# ``MaxVol``

Select high-volume row submatrices from dense matrices using Swift and
Accelerate.

## Overview

MaxVol provides Swift-native APIs for selecting representative rows from tall
dense matrices. The implementation supports real-valued `Double` and `Float`
matrices stored in column-major order so the package can call Accelerate BLAS
and LAPACK routines directly.

Use ``DenseColumnMajorMatrix`` to make matrix layout explicit at API
boundaries:

```swift
let matrix = try DenseColumnMajorMatrix(
    rows: 4,
    columns: 2,
    rowMajorValues: [
        1.0, 0.0,
        0.0, 1.0,
        0.5, 0.25,
        -0.25, 0.75,
    ]
)
```

Use `DenseColumnMajorMatrix<Float>` for the single-precision path; the public
algorithm calls keep the same shape.

Call ``maxVol(_:options:)->MaxVolResult<Double>`` or
``maxVol(_:options:)->MaxVolResult<Float>`` to select a square basis from a
tall matrix:

```swift
let result = try maxVol(matrix)

print(result.selectedRows)
print(result.iterations)
print(result.converged)
```

The returned coefficients reconstruct the original matrix from the selected
rows:

```swift
// A ~= C * A[selectedRows, :]
let coefficients = result.coefficients
```

Call ``rectMaxVol(_:options:)->MaxVolResult<Double>`` or
``rectMaxVol(_:options:)->MaxVolResult<Float>`` when the basis may contain more
rows than the matrix column count:

```swift
let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(minRows: 3))
```

## Topics

### Matrix Storage

- ``DenseColumnMajorMatrix``

### MaxVol

- ``maxVol(_:options:)->MaxVolResult<Double>``
- ``maxVol(_:options:)->MaxVolResult<Float>``
- ``rectMaxVol(_:options:)->MaxVolResult<Double>``
- ``rectMaxVol(_:options:)->MaxVolResult<Float>``
- ``MaxVolOptions``
- ``RectMaxVolOptions``
- ``MaxVolResult``
- ``MaxVolError``

### Algorithm Notes

- <doc:ToleranceAndConvergence>
- <doc:BenchmarkingAndParity>
