#!/usr/bin/env bash
set -eEuo pipefail

echo "Building TigerBeetle..."
(cd tigerbeetle && ./zig/zig build install -Dcpu=baseline -Drelease-safe)

echo "Formatting replica ..."

FILE="./0_0.tigerbeetle.bench"
if [ -f "$FILE" ]; then
    rm "$FILE"
fi

./tigerbeetle/tigerbeetle format --cluster=0 --replica=0 "$FILE"

echo "Starting tigerbeetle ..."
./tigerbeetle/tigerbeetle start --addresses=3000 "$FILE"
