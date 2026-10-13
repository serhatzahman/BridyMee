#!/bin/bash
# BridyMee Server Runner (Termux / Linux / Raspberry Pi)
set -e

echo "=== Starting BridyMee Bridge Server ==="
cd "$(dirname "$0")"

if [ ! -f "wp-server" ]; then
    echo "Building wp-server binary..."
    go build -o wp-server main.go
fi

echo "Starting server on port 8082..."
./wp-server
