# MaxVol

Swift implementations of MaxVol and RectMaxVol row-selection algorithms backed
by Accelerate.

## Goal

This package should provide small, explicit Swift APIs for selecting high-volume
row submatrices from tall dense matrices. The first implementation target is a
real-valued `Double` path using Accelerate BLAS/LAPACK, with `Float` support
following the same shape once the API is settled.

## Implementation Plan

1. Define a narrow matrix storage type.
   - Store dense matrices in column-major order to match LAPACK.
   - Keep dimensions explicit and validate shape before calling Accelerate.
   - Return descriptive errors for non-tall, rank-deficient, or malformed input.

2. Implement square MaxVol for `Double`.
   - Accept an `N x r` matrix where `N >= r`.
   - Initialize pivots with `dgetrf`.
   - Solve for expansion coefficients with triangular solves.
   - Iterate row swaps using the standard rank-one update with `dger`.
   - Return selected row indices, coefficient matrix, and iteration count.

3. Add RectMaxVol on top of square MaxVol.
   - Start from square MaxVol pivots.
   - Greedily append rows while coefficient row norms exceed tolerance.
   - Update coefficients with BLAS rank-one operations.
   - Support fixed `minRows` / `maxRows` bounds.

4. Add correctness tests before optimizing.
   - Verify reconstruction `A ~= C * A[pivots, :]`.
   - Check pivot count, uniqueness, and bounds.
   - Cover identity, tall random, rank-deficient, tolerance, and max-iteration cases.
   - Compare small deterministic fixtures against a reference Python or Julia result.

5. Add performance-focused refinements only after the behavior is stable.
   - Avoid repeated temporary allocations in the swap loop.
   - Reuse workspace buffers.
   - Add `Float` variants mapped to `sgetrf`, `strsm`, and `sger`.
   - Consider complex support only after real-valued APIs are stable.

## Non-Goals For The First Pass

- Exact exhaustive maximum-volume search.
- Sparse matrices.
- GPU kernels.
- Core ML model execution.
- Public API compatibility promises before the first tagged release.
