import Accelerate

private typealias LAPACKInt = __CLPK_integer

/// Selects a high-volume square row basis from a tall dense `Double` matrix.
///
/// The returned coefficients are shaped so the input matrix `A` can be
/// approximated by `C * A[selectedRows, :]`, where `C` is
/// ``MaxVolResult/coefficients``.
public func maxVol(
    _ matrix: DenseColumnMajorMatrix<Double>,
    options: MaxVolOptions = MaxVolOptions()
) throws -> MaxVolResult<Double> {
    let input = try matrix.validatedTallMatrix()
    let options = try options.validated()
    var selectedRows = try initialPivotRows(for: input)
    var coefficients = try expansionCoefficients(for: input, selectedRows: selectedRows)
    let maxIterations = options.maxIterations ?? max(1, input.rows * input.columns)
    var iterations = 0

    while true {
        let pivot = maximumMagnitude(in: coefficients)
        guard pivot.value > options.tolerance else {
            return try MaxVolResult(
                selectedRows: selectedRows,
                coefficients: coefficients,
                iterations: iterations
            )
        }
        guard iterations < maxIterations else {
            throw MaxVolError.maximumIterationsExceeded(limit: maxIterations)
        }

        selectedRows[pivot.column] = pivot.row
        try replaceBasisRow(
            pivotRow: pivot.row,
            pivotColumn: pivot.column,
            coefficients: &coefficients
        )
        iterations += 1
    }
}

private struct CoefficientPivot {
    let row: Int
    let column: Int
    let value: Double
}

private func initialPivotRows(for matrix: DenseColumnMajorMatrix<Double>) throws -> [Int] {
    var factorization = matrix.values
    var rowCount = try lapackInt(matrix.rows)
    var columnCount = try lapackInt(matrix.columns)
    var leadingDimension = try lapackInt(matrix.leadingDimension)
    var pivots = Array(repeating: LAPACKInt(0), count: matrix.columns)
    var info = LAPACKInt(0)

    factorization.withUnsafeMutableBufferPointer { factorBuffer -> Void in
        pivots.withUnsafeMutableBufferPointer { pivotBuffer -> Void in
            dgetrf_(
                &rowCount,
                &columnCount,
                factorBuffer.baseAddress,
                &leadingDimension,
                pivotBuffer.baseAddress,
                &info
            )
        }
    }

    try validateLapackInfo(info, routine: "dgetrf", rankDeficientInfoIsPivot: true)

    var permutation = Array(0..<matrix.rows)
    for pivotIndex in 0..<matrix.columns {
        let swappedRow = Int(pivots[pivotIndex]) - 1
        permutation.swapAt(pivotIndex, swappedRow)
    }

    return Array(permutation.prefix(matrix.columns))
}

private func expansionCoefficients(
    for matrix: DenseColumnMajorMatrix<Double>,
    selectedRows: [Int]
) throws -> DenseColumnMajorMatrix<Double> {
    let rank = selectedRows.count
    var basisValues = selectedRowsForBasis(matrix: matrix, selectedRows: selectedRows)
    var rowRankDimension = try lapackInt(rank)
    var columnRankDimension = try lapackInt(rank)
    var leadingDimension = try lapackInt(rank)
    var pivots = Array(repeating: LAPACKInt(0), count: rank)
    var info = LAPACKInt(0)

    basisValues.withUnsafeMutableBufferPointer { basisBuffer -> Void in
        pivots.withUnsafeMutableBufferPointer { pivotBuffer -> Void in
            dgetrf_(
                &rowRankDimension,
                &columnRankDimension,
                basisBuffer.baseAddress,
                &leadingDimension,
                pivotBuffer.baseAddress,
                &info
            )
        }
    }

    try validateLapackInfo(info, routine: "dgetrf", rankDeficientInfoIsPivot: true)
    try validateNonsingularFactorization(basisValues, dimension: rank)

    var transposedRightHandSide = transposedValues(matrix)
    var transpose = CChar(UInt8(ascii: "T"))
    var solveRankDimension = try lapackInt(rank)
    var basisLeadingDimension = try lapackInt(rank)
    var rightHandSideLeadingDimension = try lapackInt(rank)
    var rightHandSides = try lapackInt(matrix.rows)
    info = 0

    basisValues.withUnsafeMutableBufferPointer { basisBuffer -> Void in
        pivots.withUnsafeMutableBufferPointer { pivotBuffer -> Void in
            transposedRightHandSide.withUnsafeMutableBufferPointer { rightHandSideBuffer -> Void in
                dgetrs_(
                    &transpose,
                    &solveRankDimension,
                    &rightHandSides,
                    basisBuffer.baseAddress,
                    &basisLeadingDimension,
                    pivotBuffer.baseAddress,
                    rightHandSideBuffer.baseAddress,
                    &rightHandSideLeadingDimension,
                    &info
                )
            }
        }
    }

    try validateLapackInfo(info, routine: "dgetrs", rankDeficientInfoIsPivot: false)

    let coefficientValues = (0..<rank).flatMap { coefficientColumn in
        (0..<matrix.rows).map { row in
            transposedRightHandSide[row * rank + coefficientColumn]
        }
    }

    return try DenseColumnMajorMatrix(
        rows: matrix.rows,
        columns: rank,
        columnMajorValues: coefficientValues
    )
}

private func selectedRowsForBasis(
    matrix: DenseColumnMajorMatrix<Double>,
    selectedRows: [Int]
) -> [Double] {
    (0..<matrix.columns).flatMap { column in
        selectedRows.map { row in
            matrix[row: row, column: column]
        }
    }
}

private func transposedValues(_ matrix: DenseColumnMajorMatrix<Double>) -> [Double] {
    (0..<matrix.rows).flatMap { row in
        (0..<matrix.columns).map { column in
            matrix[row: row, column: column]
        }
    }
}

private func maximumMagnitude(in coefficients: DenseColumnMajorMatrix<Double>) -> CoefficientPivot {
    var pivot = CoefficientPivot(row: 0, column: 0, value: abs(coefficients[row: 0, column: 0]))

    for column in 0..<coefficients.columns {
        for row in 0..<coefficients.rows {
            let magnitude = abs(coefficients[row: row, column: column])
            if magnitude > pivot.value {
                pivot = CoefficientPivot(row: row, column: column, value: magnitude)
            }
        }
    }

    return pivot
}

private func replaceBasisRow(
    pivotRow: Int,
    pivotColumn: Int,
    coefficients: inout DenseColumnMajorMatrix<Double>
) throws {
    let gamma = coefficients[row: pivotRow, column: pivotColumn]
    guard gamma != 0 else {
        throw MaxVolError.rankDeficient(pivot: pivotColumn)
    }

    let replacementColumn = (0..<coefficients.rows).map { row in
        coefficients[row: row, column: pivotColumn] / gamma
    }
    let replacementRow = try coefficients.row(pivotRow)
    let rowCount = try lapackInt(coefficients.rows)
    let columnCount = try lapackInt(coefficients.columns)
    let increment = LAPACKInt(1)
    let leadingDimension = try lapackInt(coefficients.leadingDimension)

    replacementColumn.withUnsafeBufferPointer { columnBuffer -> Void in
        replacementRow.withUnsafeBufferPointer { rowBuffer -> Void in
            coefficients.values.withUnsafeMutableBufferPointer { coefficientBuffer -> Void in
                cblas_dger(
                    CblasColMajor,
                    rowCount,
                    columnCount,
                    -1,
                    columnBuffer.baseAddress,
                    increment,
                    rowBuffer.baseAddress,
                    increment,
                    coefficientBuffer.baseAddress,
                    leadingDimension
                )
            }
        }
    }

    for row in 0..<coefficients.rows {
        coefficients[row: row, column: pivotColumn] += replacementColumn[row]
    }
}

private func lapackInt(_ value: Int) throws -> LAPACKInt {
    guard value <= Int(LAPACKInt.max) else {
        throw MaxVolError.invalidDimensions(rows: value, columns: value)
    }

    return LAPACKInt(value)
}

private func validateNonsingularFactorization(_ values: [Double], dimension: Int) throws {
    let scale = max(values.map(abs).max() ?? 0, 1)
    let threshold = Double.ulpOfOne * Double(dimension) * scale

    for pivot in 0..<dimension {
        let diagonal = values[pivot * dimension + pivot]
        guard abs(diagonal) > threshold else {
            throw MaxVolError.rankDeficient(pivot: pivot + 1)
        }
    }
}

private func validateLapackInfo(
    _ info: LAPACKInt,
    routine: String,
    rankDeficientInfoIsPivot: Bool
) throws {
    if info < 0 {
        throw MaxVolError.lapackFailure(routine: routine, info: Int32(info))
    }
    if info > 0 {
        if rankDeficientInfoIsPivot {
            throw MaxVolError.rankDeficient(pivot: Int(info))
        }
        throw MaxVolError.lapackFailure(routine: routine, info: Int32(info))
    }
}
