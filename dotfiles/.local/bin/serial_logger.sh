#!/usr/bin/env bash

# ---------------------------------------------
# Serial Logger Script
#
# This script configures a serial port and logs
# everything received from it into a file.
#
# Usage:
#   ./serial_logger_pi.sh [device] [logfile]
#
# Examples:
#   ./serial_logger_pi.sh
#   ./serial_logger_pi.sh /dev/ttyUSB1
#   ./serial_logger_pi.sh /dev/ttyUSB1 my_log.log
#
# If no device is provided, /dev/ttyUSB0 is used.
# If no logfile is provided, output.log is used.
# ---------------------------------------------

# Use the first argument as the serial device.
# If no argument is given, default to /dev/ttyUSB0.
DEVICE="${1:-/dev/ttyUSB0}"

# Use the second argument as the log file.
# If no argument is given, default to output.log.
LOGFILE="${2:-output.log}"

echo "Using serial device: $DEVICE"
echo "Logging output to: $LOGFILE"

# Verify that the device exists.
if [ ! -e "$DEVICE" ]; then
    echo "Error: Device $DEVICE does not exist."
    exit 1
fi

# --------------------------------------------------
# Check if a logger is already running for this device
# --------------------------------------------------
# We look for a process that is already running
# "cat <device>". If found, we stop the script to
# avoid two processes reading the same serial port.

EXISTING_PID=$(pgrep -f "cat $DEVICE")

if [ -n "$EXISTING_PID" ]; then
    echo "A serial logger is already running for $DEVICE"
    echo "PID: $EXISTING_PID"
    echo "Stop it first with:"
    echo "  kill $EXISTING_PID"
    exit 1
fi

# --------------------------------------------------
# Configure the serial port
# --------------------------------------------------
# 115200  -> baud rate
# raw     -> disable input/output processing
# -echo   -> do not echo received characters
# -ixon/-ixoff -> disable software flow control
# -crtscts -> disable hardware flow control

stty -F "$DEVICE" 115200 raw -echo -ixon -ixoff -crtscts

# --------------------------------------------------
# Start logging
# --------------------------------------------------
# setsid creates a new session so the process is
# detached from the terminal. This allows the logger
# to continue running even after closing the shell.

setsid cat "$DEVICE" >> "$LOGFILE" 2>&1 &

# Save the process ID of the background logger.
LOGGER_PID=$!

echo "Serial logging started."
echo "Logger PID: $LOGGER_PID"
echo "You can safely close the terminal."
echo "To stop logging later run:"
echo "  kill $LOGGER_PID"
