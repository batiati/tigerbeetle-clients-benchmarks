#!/usr/bin/env bash

# zig build run -Doptimize=ReleaseSafe
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target run

