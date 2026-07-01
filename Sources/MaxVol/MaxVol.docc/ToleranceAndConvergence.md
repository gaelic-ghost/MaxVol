# Tolerance and Convergence

Use tolerance, iteration limits, and row-count bounds to decide how much work
MaxVol should do before returning a basis.

## Overview

MaxVol returns a ``MaxVolResult`` instead of only returning selected row indices
so callers can inspect the stopping behavior. The ``MaxVolResult/converged``
flag reports whether the configured stopping criterion was satisfied, while
``MaxVolResult/iterations`` reports how many update steps ran after the initial
basis was chosen.

For an input matrix `A`, both square and rectangular results use the same
reconstruction shape:

```swift
// A ~= C * A[selectedRows, :]
let selectedRows = result.selectedRows
let coefficients = result.coefficients
```

## Square MaxVol

``maxVol(_:options:)->MaxVolResult<Double>`` and
``maxVol(_:options:)->MaxVolResult<Float>`` select exactly one row per matrix
column. The square algorithm starts from an LU-pivoted basis, computes expansion
coefficients, and swaps rows while any coefficient magnitude is larger than
``MaxVolOptions/tolerance``.

The square tolerance must be at least `1.0`. Values closer to `1.0` usually do
more row swaps and produce a stronger local maximum-volume basis. Larger values
allow earlier stopping.

If ``MaxVolOptions/maxIterations`` is reached first, the result is still
validated and reconstructs through its current selected rows, but
``MaxVolResult/converged`` is `false`.

## RectMaxVol

``rectMaxVol(_:options:)->MaxVolResult<Double>`` and
``rectMaxVol(_:options:)->MaxVolResult<Float>`` start from square MaxVol, then
append extra rows. The rectangular stopping test uses coefficient row norms
instead of individual coefficient magnitudes: unselected rows are appended while
their coefficient row norm exceeds ``RectMaxVolOptions/tolerance``.

``RectMaxVolOptions/minRows`` can force extra rows even when the tolerance is
already satisfied. ``RectMaxVolOptions/maxRows`` can stop the append loop before
the tolerance is satisfied; in that case ``MaxVolResult/converged`` is `false`.
When every row is selected, the result is considered converged because there are
no unselected coefficient rows left to violate the tolerance.

## Choosing Options

Use the default options first for general row-basis selection. Tighten square
``MaxVolOptions/tolerance`` or raise ``MaxVolOptions/maxIterations`` when a
stronger square basis matters. For rectangular selection, set
``RectMaxVolOptions/minRows`` when a downstream approximation requires a minimum
basis size, and set ``RectMaxVolOptions/maxRows`` when runtime or storage must
be bounded.

The same option types apply to both `Double` and `Float` overloads. Tolerances
are expressed as `Double` values so callers can keep one configuration surface
while the numerical work uses the matrix scalar type.

## Topics

### Related APIs

- ``maxVol(_:options:)->MaxVolResult<Double>``
- ``maxVol(_:options:)->MaxVolResult<Float>``
- ``rectMaxVol(_:options:)->MaxVolResult<Double>``
- ``rectMaxVol(_:options:)->MaxVolResult<Float>``
- ``MaxVolOptions``
- ``RectMaxVolOptions``
- ``MaxVolResult``
- ``MaxVolResult/converged``
- ``MaxVolResult/iterations``
