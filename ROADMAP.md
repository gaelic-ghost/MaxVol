# MaxVol Roadmap

## Current Focus

- Tighten the dense column-major storage and public result/error surfaces before
  building algorithm behavior on top.
- Keep the first algorithm path focused on real-valued `Double` matrices backed
  by Accelerate BLAS/LAPACK.
- Preserve Swift Testing as the package test surface and expand coverage before
  optimizing.

## Algorithm Milestones

1. Implement square MaxVol for `Double`.
   - Accept a tall or square `DenseColumnMajorMatrix<Double>` where
     `rows >= columns`.
   - Initialize pivots with Accelerate LAPACK LU factorization.
   - Solve expansion coefficients with Accelerate triangular solve routines.
   - Iterate row swaps with BLAS rank-one updates.
   - Return selected row indices, coefficient matrix, and iteration count.

2. Add RectMaxVol for `Double`.
   - Start from square MaxVol selected rows.
   - Append rows while coefficient row norms exceed tolerance.
   - Support explicit `minRows` and `maxRows` bounds.
   - Reuse coefficient-update primitives from square MaxVol where practical.

3. Add `Float` support after the `Double` API is stable.
   - Mirror the `Double` API shape.
   - Map to the matching single-precision Accelerate entry points.
   - Keep shared validation and result semantics identical.

## Test Coverage

- Cover matrix storage, checked access, shape validation, and result invariants.
- Verify selected row count, uniqueness, and bounds.
- Verify reconstruction: `A ~= C * A[selectedRows, :]`.
- Cover identity, square, tall deterministic, rank-deficient, tolerance, and
  maximum-iteration cases.
- Add small deterministic fixtures generated from a reference Python, Julia, or
  R implementation.
- Add Release-mode validation once behavior depends on optimization-sensitive
  Accelerate calls.

## Documentation

- Add a DocC catalog for the package.
- Document column-major storage and the relationship to Accelerate/LAPACK leading
  dimensions.
- Document square MaxVol and RectMaxVol usage with small examples.
- Include algorithm limitations and non-goals before the first tagged release.
- Keep public API docs aligned with tested behavior.

## Swift Package Index

- Add SPI readiness checks before the first public release.
- Add `.spi.yml` only when package metadata or DocC configuration needs explicit
  SPI customization.
- Verify `swift package dump-package`, `swift build`, `swift test`, and DocC
  generation before submitting to Swift Package Index.
- Submit only after the GitHub repository is public and a SemVer tag exists.

## GitHub Publication

- Create a public `gaelic-ghost/MaxVol` GitHub repository.
- Set a concise repository description and high-signal topics.
- Push the feature branch and open a focused pull request before merging to
  `main`.
- Do not create a tagged release until square MaxVol has tested behavior and
  documentation is present.
