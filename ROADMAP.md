# MaxVol Roadmap

## Current Focus

- Build from `v0.8.0` toward `v1.0.0` with real-valued `Double` and `Float`
  algorithms backed by modern Accelerate BLAS/LAPACK.
- Keep Swift Testing as the package test surface and require reference fixtures
  before broadening the algorithm surface.
- Treat public API compatibility as pre-1.0 until reference parity,
  performance behavior, and documentation are complete enough to support a
  stable contract.

## Algorithm Milestones

1. Implement square MaxVol for `Double` and `Float`.
   - Accept a tall or square `DenseColumnMajorMatrix<Double>` or
     `DenseColumnMajorMatrix<Float>` where
     `rows >= columns`.
   - Initialize pivots with Accelerate LAPACK LU factorization.
   - Solve expansion coefficients with Accelerate triangular solve routines.
   - Iterate row swaps with BLAS rank-one updates.
   - Return selected row indices, coefficient matrix, iteration count, and
     convergence status.

2. Add RectMaxVol for `Double` and `Float`.
   - Start from square MaxVol selected rows.
   - Append rows while coefficient row norms exceed tolerance.
   - Support explicit `minRows` and `maxRows` bounds.
   - Reuse coefficient-update primitives from square MaxVol where practical.

3. Add reference-parity fixtures for each supported algorithm.
   - Keep small deterministic fixtures generated from `maxvolpy`, `Maxvol.jl`,
     or an R implementation.
   - Record selected rows, coefficients, iteration counts, and convergence
     status for fixture matrices that require zero, one, and multiple swaps.
   - Include independent reconstruction checks for every fixture.

4. Add performance-focused refinements.
   - Reduce temporary allocations in square row swaps and rectangular appends.
   - Reuse workspace buffers where it improves measured throughput.
   - Add benchmark coverage for representative row counts and ranks.
   - Compare Swift Release-mode results with official `maxvolpy` runs on shared
     deterministic fixtures before changing allocation behavior.

## Test Coverage

- Cover matrix storage, checked access, shape validation, and result invariants.
- Verify selected row count, uniqueness, and bounds.
- Verify reconstruction: `A ~= C * A[selectedRows, :]`.
- Cover identity, square, tall deterministic, rank-deficient, tolerance, and
  maximum-iteration cases.
- Keep reference fixtures generated from upstream Python, Julia, or R
  implementations when algorithm behavior changes.
- Keep randomized orthonormal-matrix tests similar to `Maxvol.jl` across
  supported scalar types.
- Keep benchmark fixture parity checks available for every supported scalar and
  algorithm family.
- Keep Release-mode validation in the release path for optimization-sensitive
  Accelerate calls.
- Keep validation clean under the modern Accelerate `ACCELERATE_NEW_LAPACK` and
  `ACCELERATE_LAPACK_ILP64` import surface.

## Documentation

- Maintain the DocC catalog for the package.
- Document column-major storage and the relationship to Accelerate/LAPACK leading
  dimensions.
- Document square MaxVol and RectMaxVol usage with small examples.
- Keep algorithm limitations and non-goals visible before `1.0.0`.
- Keep public API docs aligned with tested behavior.
- Expand DocC with algorithm notes, limitations, and reference-fixture
  provenance before `1.0.0`.
- Keep benchmark and profiling commands documented so performance work remains
  reproducible.

## Swift Package Index

- Swift Package Index submission has been started for the public package.
- Keep SPI readiness checks in the release path.
- Keep `.spi.yml` aligned with DocC targets when package documentation changes.
- Verify `swift package dump-package`, `swift build`, `swift test`, and DocC
  generation before each tagged release.
- Monitor SPI package ingestion and rendered documentation as release tags land.

## GitHub Publication

- Keep the public `gaelic-ghost/MaxVol` repository aligned with SemVer tags.
- Merge focused pull requests into `main` only after serial `swift build`,
  `swift test`, repo-maintenance validation, and DocC conversion pass.

## Before `1.0.0`

- Decide whether complex-valued matrices are in scope for `1.0.0` or explicitly
  post-1.0.
- Add broader randomized numerical tests, including stress cases for larger
  ranks, wider condition-number ranges, and deterministic tie behavior.
- Add performance benchmarks for allocation count, row-swap throughput, and
  rectangular append throughput.
- Profile whether reusable workspaces are worth adding to the public API or
  should remain an internal optimization.
- Expand DocC with reference-fixture provenance and a short comparison with
  Python, Julia, and R implementations.
- Verify Swift Package Index renders the tagged `v1.0.0` documentation cleanly.

## Planned `v0.9.0`

- Use `MaxVolBenchmark` and the `maxvolpy` comparison harness as the baseline
  evidence source before changing performance-sensitive code.
- Measure Release-mode square row-swap throughput and RectMaxVol append
  throughput across the checked-in deterministic fixture set.
- Capture allocation traces for the largest fixtures and identify temporary
  buffers created inside coefficient construction, square row replacement, and
  rectangular appends.
- Decide whether reusable workspaces should remain an internal optimization or
  become a public advanced API.
- Implement only measured allocation reductions, then re-run parity, timing, and
  allocation checks before tagging `v0.9.0`.
