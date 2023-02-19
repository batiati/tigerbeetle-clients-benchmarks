#!/usr/bin/env bash
set -eEuo pipefail

echo "Installing TigerBeetle..."
git submodule init && git submodule update
(cd tigerbeetle && git submodule init && git submodule update && ./scripts/install_zig.sh)

echo "Building TigerBeetle Dotnet..."
(cd tigerbeetle/src/clients/dotnet && dotnet build -c Release && dotnet pack -c Release)

echo "Building TigerBeetle Java..."
(cd tigerbeetle/src/clients/java && mvn -B package)
