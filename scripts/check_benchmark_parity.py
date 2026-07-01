#!/usr/bin/env python3
"""Compare MaxVolBenchmark JSONL with maxvolpy JSONL for correctness parity."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def load_records(path: Path) -> dict[tuple[str, str, str], dict[str, Any]]:
    records: dict[tuple[str, str, str], dict[str, Any]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        key = (record["fixture"], record["algorithm"], record["scalar"])
        records[key] = record
    return records


def tolerance_for(scalar: str) -> float:
    return 1e-4 if scalar == "float" else 1e-8


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("swift_jsonl", type=Path)
    parser.add_argument("python_jsonl", type=Path)
    args = parser.parse_args()

    swift_records = load_records(args.swift_jsonl)
    python_records = load_records(args.python_jsonl)

    missing_from_python = sorted(set(swift_records) - set(python_records))
    missing_from_swift = sorted(set(python_records) - set(swift_records))
    if missing_from_python or missing_from_swift:
        raise SystemExit(
            "Benchmark result keys differ. "
            f"Missing from Python: {missing_from_python}. "
            f"Missing from Swift: {missing_from_swift}."
        )

    failures: list[str] = []
    for key in sorted(swift_records):
        swift = swift_records[key]
        python = python_records[key]
        tolerance = tolerance_for(swift["scalar"])

        if swift["selectedRowCount"] != python["selectedRowCount"]:
            failures.append(
                f"{key}: selected row count differs "
                f"Swift={swift['selectedRowCount']} Python={python['selectedRowCount']}"
            )

        residual_delta = abs(swift["reconstructionResidual"] - python["reconstructionResidual"])
        if residual_delta > tolerance:
            failures.append(
                f"{key}: reconstruction residual differs by {residual_delta}, tolerance {tolerance}"
            )

        swift_norm = swift.get("maxUnselectedRowNorm")
        python_norm = python.get("maxUnselectedRowNorm")
        if swift_norm is not None and python_norm is not None and abs(swift_norm - python_norm) > tolerance:
            failures.append(
                f"{key}: rectangular row norm differs "
                f"Swift={swift_norm} Python={python_norm}, tolerance {tolerance}"
            )

    if failures:
        raise SystemExit("\n".join(failures))

    print(f"Benchmark parity passed for {len(swift_records)} result keys.")


if __name__ == "__main__":
    main()
