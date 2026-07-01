#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.12"
# dependencies = [
#   "numpy==1.26.4",
#   "scipy==1.11.4",
# ]
# ///
"""Run the official maxvolpy implementation against MaxVol benchmark fixtures."""

from __future__ import annotations

import argparse
import contextlib
import importlib
import json
import sys
import tarfile
import time
import urllib.request
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any

import numpy as np


MAXVOLPY_VERSION = "0.3.8"
MAXVOLPY_SDIST_URL = (
    "https://files.pythonhosted.org/packages/4a/cd/"
    "142dc96f91db394c4a9c212c59ee17e67e3324dba6ff05346d269d5b6731/"
    "maxvolpy-0.3.8.tar.gz"
)


def safe_extract(source: tarfile.TarFile, destination: Path) -> None:
    destination = destination.resolve()
    for member in source.getmembers():
        target = (destination / member.name).resolve()
        if not target.is_relative_to(destination):
            raise RuntimeError(f"Refusing to extract unsafe maxvolpy archive member: {member.name}")
    source.extractall(destination)


def load_maxvol_module(source_dir: Path | None):
    if source_dir is None:
        with TemporaryDirectory(prefix="maxvolpy-") as temporary_directory:
            source_dir = Path(temporary_directory)
            archive = source_dir / "maxvolpy.tar.gz"
            urllib.request.urlretrieve(MAXVOLPY_SDIST_URL, archive)
            with tarfile.open(archive) as tar:
                safe_extract(tar, source_dir)
            package_root = source_dir / f"maxvolpy-{MAXVOLPY_VERSION}"
            sys.path.insert(0, str(package_root))
            with contextlib.redirect_stdout(sys.stderr):
                return importlib.import_module("maxvolpy.maxvol")

    sys.path.insert(0, str(source_dir))
    with contextlib.redirect_stdout(sys.stderr):
        return importlib.import_module("maxvolpy.maxvol")


def run_algorithm(module: Any, matrix: np.ndarray, algorithm: str, implementation: str):
    if algorithm == "square":
        function = module.py_maxvol if implementation == "pure" else module.maxvol
        return function(matrix, tol=1.05, max_iters=200)

    function = module.py_rect_maxvol if implementation == "pure" else module.rect_maxvol
    return function(matrix, tol=1.0, start_maxvol_iters=10)


def reconstruction_residual(matrix: np.ndarray, pivots: np.ndarray, coefficients: np.ndarray) -> float:
    reconstructed = coefficients.dot(matrix[pivots])
    return float(np.max(np.abs(matrix - reconstructed)))


def max_unselected_row_norm(pivots: np.ndarray, coefficients: np.ndarray) -> float | None:
    selected = set(int(row) for row in pivots)
    norms = [
        float(np.linalg.norm(coefficients[row], ord=2))
        for row in range(coefficients.shape[0])
        if row not in selected
    ]
    return max(norms) if norms else 0.0


def benchmark_fixture(
    module: Any,
    fixture: dict[str, Any],
    algorithm: str,
    scalar: str,
    implementation: str,
    repetitions: int,
) -> dict[str, Any]:
    dtype = np.float32 if scalar == "float" else np.float64
    matrix = np.array(fixture["rowMajorValues"], dtype=dtype).reshape(fixture["rows"], fixture["columns"])
    run_algorithm(module, matrix, algorithm, implementation)

    start = time.perf_counter_ns()
    pivots, coefficients = run_algorithm(module, matrix, algorithm, implementation)
    for _ in range(1, repetitions):
        pivots, coefficients = run_algorithm(module, matrix, algorithm, implementation)
    elapsed = time.perf_counter_ns() - start

    return {
        "tool": "maxvolpy",
        "implementation": implementation,
        "fixture": fixture["id"],
        "algorithm": algorithm,
        "scalar": scalar,
        "rows": fixture["rows"],
        "columns": fixture["columns"],
        "repetitions": repetitions,
        "elapsedNanoseconds": elapsed,
        "averageNanoseconds": elapsed / repetitions,
        "selectedRowCount": int(len(pivots)),
        "algorithmIterations": None,
        "converged": None,
        "maxCoefficientMagnitude": float(np.max(np.abs(coefficients))),
        "maxUnselectedRowNorm": (
            max_unselected_row_norm(pivots, coefficients)
            if algorithm == "rectangular"
            else None
        ),
        "reconstructionResidual": reconstruction_residual(matrix, pivots, coefficients),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", default="Sources/MaxVolBenchmark/Resources/fixtures.json")
    parser.add_argument("--fixture")
    parser.add_argument("--algorithm", choices=["all", "square", "rectangular"], default="all")
    parser.add_argument("--scalar", choices=["all", "double", "float"], default="all")
    parser.add_argument("--implementation", choices=["pure", "api"], default="pure")
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--maxvolpy-source-dir", type=Path)
    args = parser.parse_args()

    if args.iterations <= 0:
        raise SystemExit("--iterations must be greater than zero.")

    fixtures_file = json.loads(Path(args.fixtures).read_text(encoding="utf-8"))
    fixtures = fixtures_file["fixtures"]
    if args.fixture is not None:
        fixtures = [fixture for fixture in fixtures if fixture["id"] == args.fixture]
        if not fixtures:
            raise SystemExit(f"No benchmark fixture matched '{args.fixture}'.")

    algorithms = ["square", "rectangular"] if args.algorithm == "all" else [args.algorithm]
    scalars = ["double", "float"] if args.scalar == "all" else [args.scalar]
    module = load_maxvol_module(args.maxvolpy_source_dir)

    for fixture in fixtures:
        for algorithm in algorithms:
            for scalar in scalars:
                print(
                    json.dumps(
                        benchmark_fixture(
                            module,
                            fixture,
                            algorithm,
                            scalar,
                            args.implementation,
                            args.iterations,
                        ),
                        sort_keys=True,
                    )
                )


if __name__ == "__main__":
    main()
