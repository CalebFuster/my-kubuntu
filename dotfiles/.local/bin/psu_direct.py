#!/usr/bin/env python3
# Copyright (c) 2026 Quantica GmbH. All rights reserved.
"""
psu_direct.py — Korad KA3010P power supply CLI controller.

Usage:
    python3 psu_direct.py [--port PORT] <command> [args...]

Commands:
    idn                     Identify device
    vset <mV>               Set voltage in mV (e.g. 12000 → 12.00 V)
    iset <mA>               Set current in mA (e.g. 1500 → 1.500 A)
    vset?                   Read programmed voltage
    iset?                   Read programmed current
    vout?                   Read actual output voltage
    iout?                   Read actual output current
    out <on|off>            Enable or disable output
    status                  Read status byte (CV/CC/output state)
    ovp <on|off>            Over-voltage protection
    ocp <on|off>            Over-current protection
    beep <on|off>           Beeper
    sav <1-5>               Save to preset slot
    rcl <1-5>               Recall preset slot
"""

import argparse
import sys
import time

import serial

DEFAULT_PORT = "/dev/ttyACM0"
READ_DELAY = 0.05  # seconds to wait before reading a response


def open_port(port: str) -> serial.Serial:
    return serial.Serial(port, baudrate=9600, bytesize=8, parity="N", stopbits=1, timeout=0.1)


def send(ser: serial.Serial, cmd: str):
    ser.write(cmd.encode())


def query(ser: serial.Serial, cmd: str) -> str:
    send(ser, cmd)
    time.sleep(READ_DELAY)
    first = ser.read(1)
    rest = ser.read(ser.in_waiting) if ser.in_waiting else b""
    return (first + rest).decode(errors="replace").strip("\x00").strip()


def query_raw(ser: serial.Serial, cmd: str, n: int = 1) -> bytes:
    send(ser, cmd)
    time.sleep(READ_DELAY)
    return ser.read(n)


def parse_status(byte_val: int):
    cv = bool(byte_val & (1 << 0))
    cc = bool(byte_val & (1 << 1))
    out = bool(byte_val & (1 << 6))
    mode = "CV" if cv else ("CC" if cc else "unknown")
    print(f"  Output : {'ON' if out else 'OFF'}")
    print(f"  Mode   : {mode}")
    print(f"  Raw    : 0x{byte_val:02X} ({byte_val:08b}b)")


def on_off_arg(val: str) -> str:
    v = val.lower()
    if v not in ("on", "off"):
        raise argparse.ArgumentTypeError("expected 'on' or 'off'")
    return v


def main():
    parser = argparse.ArgumentParser(
        description="Korad KA3010P power supply CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--port", default=DEFAULT_PORT, help=f"Serial port (default: {DEFAULT_PORT})"
    )
    parser.add_argument("command", help="Command to execute")
    parser.add_argument("args", nargs="*", help="Command arguments")

    args = parser.parse_args()
    cmd = args.command.lower()
    cargs = args.args

    try:
        ser = open_port(args.port)
    except serial.SerialException as e:
        print(f"Error opening {args.port}: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        # --- identification ---
        if cmd == "idn":
            print(query(ser, "*IDN?"))

        # --- voltage / current set ---
        elif cmd == "vset":
            if not cargs:
                parser.error("vset requires a voltage in mV")
            try:
                mv = int(cargs[0])
            except ValueError:
                parser.error(f"vset: invalid integer {cargs[0]!r}")
            volts = mv / 1000.0
            send(ser, f"VSET1:{volts:05.2f}")
            print(f"Voltage set to {mv} mV ({volts:.2f} V)")

        elif cmd == "iset":
            if not cargs:
                parser.error("iset requires a current in mA")
            try:
                ma = int(cargs[0])
            except ValueError:
                parser.error(f"iset: invalid integer {cargs[0]!r}")
            amps = ma / 1000.0
            send(ser, f"ISET1:{amps:05.3f}")
            print(f"Current set to {ma} mA ({amps:.3f} A)")

        # --- queries ---
        elif cmd == "vset?":
            print(f'Programmed voltage : {query(ser, "VSET1?")} V')

        elif cmd == "iset?":
            print(f'Programmed current : {query(ser, "ISET1?")} A')

        elif cmd == "vout?":
            print(f'Output voltage : {query(ser, "VOUT1?")} V')

        elif cmd == "iout?":
            print(f'Output current : {query(ser, "IOUT1?")} A')

        # --- output enable ---
        elif cmd == "out":
            if not cargs:
                parser.error("out requires on or off")
            v = on_off_arg(cargs[0])
            send(ser, "OUT1" if v == "on" else "OUT0")
            print(f"Output turned {v.upper()}")

        # --- status ---
        elif cmd == "status":
            raw = query_raw(ser, "STATUS?", 1)
            if raw:
                parse_status(raw[0])
            else:
                print("No response", file=sys.stderr)
                sys.exit(1)

        # --- protections / beeper ---
        elif cmd == "ovp":
            if not cargs:
                parser.error("ovp requires on or off")
            v = on_off_arg(cargs[0])
            send(ser, "OVP1" if v == "on" else "OVP0")
            print(f"OVP turned {v.upper()}")

        elif cmd == "ocp":
            if not cargs:
                parser.error("ocp requires on or off")
            v = on_off_arg(cargs[0])
            send(ser, "OCP1" if v == "on" else "OCP0")
            print(f"OCP turned {v.upper()}")

        elif cmd == "beep":
            if not cargs:
                parser.error("beep requires on or off")
            v = on_off_arg(cargs[0])
            send(ser, "BEEP1" if v == "on" else "BEEP0")
            print(f"Beeper turned {v.upper()}")

        # --- presets ---
        elif cmd == "sav":
            if not cargs or not cargs[0].isdigit() or not (1 <= int(cargs[0]) <= 5):
                parser.error("sav requires a slot number 1-5")
            send(ser, f"SAV{cargs[0]}")
            print(f"Settings saved to slot {cargs[0]}")

        elif cmd == "rcl":
            if not cargs or not cargs[0].isdigit() or not (1 <= int(cargs[0]) <= 5):
                parser.error("rcl requires a slot number 1-5")
            send(ser, f"RCL{cargs[0]}")
            print(f"Recalled slot {cargs[0]}")

        else:
            print(f"Unknown command: {cmd}", file=sys.stderr)
            parser.print_help()
            sys.exit(1)

    except serial.SerialException as e:
        print(f"Serial error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        ser.close()


if __name__ == "__main__":
    main()
