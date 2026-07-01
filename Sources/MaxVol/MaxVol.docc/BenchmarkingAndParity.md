# Benchmarking and Parity

Use the package benchmark executable and Python harness to compare MaxVol's
Accelerate-backed implementation with `maxvolpy` on identical deterministic
fixtures.

## Swift Benchmark

Build and run the benchmark executable in Release mode when measuring runtime:

```bash
swift run -c release MaxVolBenchmark --iterations 20
```

The executable reads bundled fixture values from `MaxVolBenchmark` resources and
prints JSON Lines. Each record includes the fixture, algorithm, scalar type,
selected row count, convergence status, algorithm iteration count, reconstruction
residual, coefficient magnitude, and elapsed nanoseconds.

Filter the workload when recording a focused trace:

```bash
swift run -c release MaxVolBenchmark --fixture gaussian-192x16 --algorithm square --scalar double --iterations 100
```

## Python Comparison

The Python harness downloads the official `maxvolpy` source distribution from
PyPI, imports its implementation, and runs it against the same checked-in fixture
values:

```bash
uv run --python 3.11 scripts/compare_maxvolpy.py --iterations 20
```

Use the `pure` implementation mode for the Python reference path. The `api` mode
uses `maxvolpy.maxvol` and `maxvolpy.rect_maxvol`, which may use the compiled
extension if the package is installed with one available.

## Parity Check

Compare correctness-oriented fields by writing Swift and Python output to JSONL
files:

```bash
swift run -c release MaxVolBenchmark --iterations 20 > /tmp/maxvol-swift.jsonl
uv run --python 3.11 scripts/compare_maxvolpy.py --iterations 20 > /tmp/maxvol-python.jsonl
python3 scripts/check_benchmark_parity.py /tmp/maxvol-swift.jsonl /tmp/maxvol-python.jsonl
```

The checker verifies that both runs produced the same fixture, algorithm, and
scalar keys, then compares selected row counts, reconstruction residuals, and
rectangular unselected-row norms.

## Allocation Profiling

Build before profiling so the trace captures benchmark work instead of package
resolution or compilation:

```bash
swift build -c release --product MaxVolBenchmark
xcrun xctrace record --template 'Allocations' --output /tmp/MaxVolBenchmark.trace --launch -- .build/release/MaxVolBenchmark --fixture gaussian-192x16 --iterations 100
```

Keep trace artifacts out of the repository unless a future performance report
explicitly needs to preserve one as release evidence.
