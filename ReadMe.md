# TigerBeetle Client benchmark

This benchmark compares the throughput and latency of the TigerBeetle client implemented in Zig with other programming language implementations using the tb_client API to show how the natural runtime overhead of FFI calls was minimized.

The code consists of submitting one million transfers to the TigerBeetle cluster. Since the focus is benchmarking only the client side, all transfers are sent with an invalid ID to ensure that they will be immediately rejected. It's enough work to stress the client without much server-side measurement noise.

## Prerequisites

In order to build and run all clients:

- Go > 1.17
- Dotnet SDK 6.0
- Java JDK 11+ and Maven 3.1+

## Usage

### 1. Install zig

```bash
./scripts/install.sh
```

### 2. Start a local TigerBeetle cluster

```bash
./scripts/run_tigerbeetle.sh
```

### 3. Run the benchmark for each language

```bash
echo Go
(cd go && ./run.sh)

echo Java
(cd java && ./run.sh)

echo Dotnet
(cd dotnet && ./run.sh)

echo C
(cd c && ./run.sh)

echo Zig
(cd zig && ./run.sh)
```