#!/usr/bin/env python3
# Copyright (c) 2026 Quantica GmbH. All rights reserved.
"""
psu_remote.py — Korad KA3010P interactive power supply controller.

Usage:
    python3 psu_remote.py [--voltage <mV>] [--current <mA>] [--port PORT]

Keys during monitoring:
    o   Toggle output on/off
    c   Toggle OCP on/off
    p   Toggle OVP on/off
    v   Set new voltage (mV)
    i   Set new current (mA)
    q   Turn output off and quit
    w   Quit leaving output unchanged
"""

import argparse
import select
import sys
import termios
import time
import tty

import serial

DEFAULT_PORT = "/dev/ttyACM0"
READ_DELAY = 0.05  # seconds between write and read
POLL_INTERVAL = 0.5  # monitoring refresh interval (seconds)


# ---------------------------------------------------------------------------
# Serial helpers
# ---------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------
# Terminal helpers
# ---------------------------------------------------------------------------


def kbhit() -> bool:
    return bool(select.select([sys.stdin], [], [], 0)[0])


def getch() -> str:
    return sys.stdin.read(1)


# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------


def print_layout(idn: str, vset_f: float, iset_f: float):
    """Clear the screen and print the full UI layout."""
    print("\033[2J\033[H", end="")
    print(f"Device : {idn}")
    print()
    print(f"Vset : {vset_f:7.3f} V  |  Iset : {iset_f:7.3f} A")
    print(f"Vout :   0.000 V  |  Iout :   0.000 A")
    print()
    print("Output: \033[31mOFF\033[0m   OCP: \033[31mOFF\033[0m   OVP: \033[31mOFF\033[0m")
    print()
    print(
        "[o] toggle output   [c] toggle OCP   [p] toggle OVP   [v] set voltage   [i] set current   [q] quit   [w] quit (keep output)"
    )


def update_display(vout: float, iout: float, output_on: bool, ocp_on: bool, ovp_on: bool):
    """Rewrite the dynamic lines (Vout and status) in place.

    Layout after print_layout (cursor at line 9 after hints \\r\\n):
      1: Device
      2: blank
      3: Vset / Iset       (static)
      4: Vout / Iout       (dynamic)  <- \033[5A from line 9 (after \r\n of hints)
      5: blank
      6: Output / OCP / OVP (dynamic)
      7: blank
      8: hints
      9: (cursor here after update)
    """
    out_str = "\033[32mON \033[0m" if output_on else "\033[31mOFF\033[0m"
    ocp_str = "\033[32mON \033[0m" if ocp_on else "\033[31mOFF\033[0m"
    ovp_str = "\033[32mON \033[0m" if ovp_on else "\033[31mOFF\033[0m"

    sys.stdout.write("\033[5A")  # move up to line 4 (Vout)
    sys.stdout.write(f"\r\033[2KVout : {vout:7.3f} V  |  Iout : {iout:7.3f} A\r\n")
    sys.stdout.write("\r\n")
    sys.stdout.write(f"\r\033[2KOutput: {out_str}   OCP: {ocp_str}   OVP: {ovp_str}\r\n")
    sys.stdout.write("\r\n")
    sys.stdout.write(
        "\r[o] toggle output   [c] toggle OCP   [p] toggle OVP   [v] set voltage   [i] set current   [q] quit   [w] quit (keep output)\r\n"
    )
    sys.stdout.flush()


MAX_VOLTAGE_MV = 30000
MAX_CURRENT_MA = 10000


def prompt_value(label: str, unit: str, min_val: int, max_val: int) -> int | None:
    """Prompt for an integer value. Terminal must already be in normal mode.

    Returns the integer value, or None if the user cancels or enters invalid input.
    """
    try:
        raw = input(f"\n{label} ({unit}, {min_val}–{max_val}, Enter to cancel): ")
        if not raw.strip():
            return None
        val = int(raw)
        if not (min_val <= val <= max_val):
            print(f"Out of range — keeping current {label.lower()}.")
            time.sleep(1)
            return None
        return val
    except (ValueError, EOFError):
        print(f"Invalid value — keeping current {label.lower()}.")
        time.sleep(1)
        return None
    except KeyboardInterrupt:
        return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Korad KA3010P interactive controller",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--port", default=DEFAULT_PORT, help=f"Serial port (default: {DEFAULT_PORT})"
    )
    parser.add_argument(
        "--voltage",
        type=int,
        default=None,
        metavar="mV",
        help=f"Target voltage in mV (0–{MAX_VOLTAGE_MV})",
    )
    parser.add_argument(
        "--current",
        type=int,
        default=None,
        metavar="mA",
        help=f"Current limit in mA (0–{MAX_CURRENT_MA})",
    )
    args = parser.parse_args()

    if args.voltage is not None and not (0 <= args.voltage <= MAX_VOLTAGE_MV):
        parser.error(f"--voltage must be between 0 and {MAX_VOLTAGE_MV} mV")
    if args.current is not None and not (0 <= args.current <= MAX_CURRENT_MA):
        parser.error(f"--current must be between 0 and {MAX_CURRENT_MA} mA")

    # -- Open port -----------------------------------------------------------
    try:
        ser = open_port(args.port)
    except serial.SerialException as e:
        print(f"Error opening {args.port}: {e}", file=sys.stderr)
        sys.exit(1)

    # -- Identify device -----------------------------------------------------
    idn = query(ser, "*IDN?")
    if not idn:
        print("No device found. Check connection and port.", file=sys.stderr)
        ser.close()
        sys.exit(1)

    # -- Program voltage and current (if provided) ---------------------------
    # Only disable the output when reprogramming, to avoid interrupting an
    # already-running supply when the script is attached without new setpoints.
    if args.voltage is not None or args.current is not None:
        send(ser, "OUT0")
        send(ser, "OCP0")
        time.sleep(0.1)

        vout_raw = query(ser, "VOUT1?")
        try:
            vout_now = float(vout_raw)
        except ValueError:
            vout_now = -1.0

        if vout_now != 0.0:
            print(
                f"Warning: Vout is {vout_now:.2f} V after disabling output "
                f"(expected 0.00 V — load may still be discharging)"
            )

        if args.voltage is not None:
            send(ser, f"VSET1:{args.voltage / 1000.0:05.2f}")
            time.sleep(READ_DELAY)
        if args.current is not None:
            send(ser, f"ISET1:{args.current / 1000.0:05.3f}")
            time.sleep(READ_DELAY)

    vset_str = query(ser, "VSET1?")
    iset_str = query(ser, "ISET1?")
    try:
        vset_f = float(vset_str)
        iset_f = float(iset_str)
    except ValueError:
        print("Could not verify programmed values.", file=sys.stderr)
        ser.close()
        sys.exit(1)

    # -- Draw initial UI layout ----------------------------------------------
    print_layout(idn, vset_f, iset_f)

    output_on = False
    ocp_on = False
    ovp_on = False
    shutdown_output = True  # set to False by 'w' to quit without powering off

    # -- Monitoring loop (raw terminal mode) ---------------------------------
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    try:
        tty.setraw(fd)
        last_poll = 0.0

        while True:
            now = time.time()

            if now - last_poll >= POLL_INTERVAL:
                try:
                    vout = float(query(ser, "VOUT1?"))
                    iout = float(query(ser, "IOUT1?"))
                except ValueError:
                    vout = iout = float("nan")

                status_raw = query_raw(ser, "STATUS?", 1)
                if status_raw:
                    output_on = bool(status_raw[0] & (1 << 6))
                    ocp_on = bool(status_raw[0] & (1 << 5))
                    ovp_on = bool(status_raw[0] & (1 << 7))

                update_display(vout, iout, output_on, ocp_on, ovp_on)
                last_poll = now

            if kbhit():
                ch = getch().lower()
                if ch == "o":
                    output_on = not output_on
                    send(ser, "OUT1" if output_on else "OUT0")
                elif ch == "c":
                    send(ser, "OCP0" if ocp_on else "OCP1")
                elif ch == "p":
                    send(ser, "OVP0" if ovp_on else "OVP1")
                elif ch == "v":
                    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                    mv = prompt_value("Voltage", "mV", 0, MAX_VOLTAGE_MV)
                    if mv is not None:
                        vset_f = mv / 1000.0
                        send(ser, f"VSET1:{vset_f:05.2f}")
                        time.sleep(READ_DELAY)
                        vset_f = float(query(ser, "VSET1?"))
                    print_layout(idn, vset_f, iset_f)
                    tty.setraw(fd)
                    last_poll = 0.0
                elif ch == "i":
                    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                    ma = prompt_value("Current", "mA", 0, MAX_CURRENT_MA)
                    if ma is not None:
                        iset_f = ma / 1000.0
                        send(ser, f"ISET1:{iset_f:05.3f}")
                        time.sleep(READ_DELAY)
                        iset_f = float(query(ser, "ISET1?"))
                    print_layout(idn, vset_f, iset_f)
                    tty.setraw(fd)
                    last_poll = 0.0
                elif ch == "q":
                    break
                elif ch == "w":
                    shutdown_output = False
                    break

            time.sleep(0.01)

    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        if shutdown_output:
            try:
                send(ser, "OUT0")
            except Exception:
                # Best-effort attempt; ignore errors during shutdown
                pass
        ser.close()
        print("\r\nOutput OFF. Goodbye." if shutdown_output else "\r\nGoodbye.")


if __name__ == "__main__":
    main()
