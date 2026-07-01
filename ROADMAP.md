# MaxVol Roadmap

## Current Focus

- Build from `v0.5.0` toward `v1.0.0` with real-valued `Double` algorithms
  backed by modern Accelerate BLAS/LAPACK.
- Keep Swift Testing as the package test surface and require reference fixtures
  before broadening the algorithm surface.
- Treat public API compatibility as pre-1.0 until RectMaxVol, Float support, and
  reference parity are complete.

## Algorithm Milestones

1. Implement square MaxVol for `Double`.
   - Accept a tall or square `DenseColumnMajorMatrix<Double>` where
     `rows >= columns`.
   - Initialize pivots with Accelerate LAPACK LU factorization.
   - Solve expansion coefficients with Accelerate triangular solve routines.
   - Iterate row swaps with BLAS rank-one updates.
   - Return selected row indices, coefficient matrix, iteration count, and
     convergence status.

2. Add RectMaxVol for `Double`.
   - Start from square MaxVol selected rows.
   - Append rows while coefficient row norms exceed tolerance.
   - Support explicit `minRows` and `maxRows` bounds.
   - Reuse coefficient-update primitives from square MaxVol where practical.

3. Add `Float` support after the `Double` API is stable.
   - Mirror the `Double` API shape.
   - Map to the matching single-precision Accelerate entry points.
   - Keep shared validation and result semantics identical.

4. Add reference-parity fixtures for each supported algorithm.
   - Keep small deterministic fixtures generated from `maxvolpy`, `Maxvol.jl`,
     or an R implementation.
   - Record selected rows, coefficients, iteration counts, and convergence
     status for fixture matrices that require zero, one, and multiple swaps.
   - Include independent reconstruction checks for every fixture.

## Test Coverage

- Cover matrix storage, checked access, shape validation, and result invariants.
- Verify selected row count, uniqueness, and bounds.
- Verify reconstruction: `A ~= C * A[selectedRows, :]`.
- Cover identity, square, tall deterministic, rank-deficient, tolerance, and
  maximum-iteration cases.
- Keep reference fixtures generated from upstream Python, Julia, or R
  implementations when algorithm behavior changes.
- Add randomized orthonormal-matrix tests similar to `Maxvol.jl` before `1.0.0`.
- Add Release-mode validation once behavior depends on optimization-sensitive
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
- Add a DocC article that explains tolerance, convergence status, and
  iteration-limited partial results before `1.0.0`.

## Swift Package Index

- Defer Swift Package Index submission until `v1.0.0`.
- Keep SPI readiness checks in the release path.
- Keep `.spi.yml` aligned with DocC targets when package documentation changes.
- Verify `swift package dump-package`, `swift build`, `swift test`, and DocC
  generation before the eventual Swift Package Index submission.
- Submit only after the GitHub repository is public and the `v1.0.0` SemVer tag
  exists.

## GitHub Publication

- Keep the public `gaelic-ghost/MaxVol` repository aligned with SemVer tags.
- Merge focused pull requests into `main` only after serial `swift build`,
  `swift test`, repo-maintenance validation, and DocC conversion pass.
- Do not submit to Swift Package Index before `v1.0.0`.

## Before `1.0.0`

- Complete RectMaxVol for `Double` with reference-parity fixtures.
- Add `Float` support with the same API shape and reference fixtures.
- Decide whether complex-valued matrices are in scope for `1.0.0` or explicitly
  post-1.0.
- Add broader randomized numerical tests, including orthonormal tall matrices
  and near-rank-deficient cases.
- Add Release-mode validation for optimization-sensitive Accelerate behavior.
- Add performance benchmarks for allocation count and row-swap throughput.
- Expand DocC with algorithm notes, limitations, and reference-fixture
  provenance.
- Submit the tagged `v1.0.0` public package to Swift Package Index and verify
  rendered documentation.
