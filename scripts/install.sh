#!/usr/bin/env bash
set -eEuo pipefail

echo "Installing TigerBeetle..."
git clone --recursive https://github.com/tigerbeetle/tigerbeetle.git
(cd tigerbeetle && ./scripts/install_zig.sh)

echo "Building TigerBeetle Dotnet..."
(cd tigerbeetle/src/clients/dotnet && dotnet build -c Release && dotnet pack -c Release)

echo "Building TigerBeetle Java..."
(cd tigerbeetle/src/clients/java && mvn -B package)
