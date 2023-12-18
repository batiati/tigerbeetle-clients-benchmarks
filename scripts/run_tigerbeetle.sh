#!/usr/bin/env bash
set -eEuo pipefail

PATH=$PATH:$PWD/tigerbeetle/zig-out/bin

echo "Building TigerBeetle..."
(cd tigerbeetle && ./zig/zig build -Dcpu=baseline -Doptimize=ReleaseSafe)

echo "Formatting replica ..."

FILE="./0_0.tigerbeetle.bench"
if [ -f "$FILE" ]; then
    rm "$FILE"
fi

tigerbeetle format --cluster=0 --replica=0 --replica-count=1 "$FILE"

echo "Starting tigerbeetle ..."
tigerbeetle start --addresses=3000 "$FILE"&
