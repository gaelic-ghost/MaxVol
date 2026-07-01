/// Selects a high-volume square row basis from a tall dense `Double` matrix.
///
/// The returned coefficients are shaped so the input matrix `A` can be
/// approximated by `C * A[selectedRows, :]`, where `C` is
/// ``MaxVolResult/coefficients``.
public func maxVol(
    _ matrix: DenseColumnMajorMatrix<Double>,
    options: MaxVolOptions = MaxVolOptions()
) throws -> MaxVolResult<Double> {
    try maxVolImpl(matrix, options: options)
}

/// Selects a high-volume square row basis from a tall dense `Float` matrix.
///
/// The returned coefficients are shaped so the input matrix `A` can be
/// approximated by `C * A[selectedRows, :]`, where `C` is
/// ``MaxVolResult/coefficients``.
public func maxVol(
    _ matrix: DenseColumnMajorMatrix<Float>,
    options: MaxVolOptions = MaxVolOptions()
) throws -> MaxVolResult<Float> {
    try maxVolImpl(matrix, options: options)
}

func maxVolImpl<Scalar: MaxVolScalar>(
    _ matrix: DenseColumnMajorMatrix<Scalar>,
    options: MaxVolOptions = MaxVolOptions()
) throws -> MaxVolResult<Scalar> {
    let input = try matrix.validatedTallMatrix()
    let options = try options.validated()
    var selectedRows = try initialPivotRows(for: input)
    var coefficients = try expansionCoefficients(for: input, selectedRows: selectedRows)
    var iterations = 0

    while true {
        let pivot = maximumMagnitude(in: coefficients)
        guard pivot.value > options.tolerance else {
            return try MaxVolResult(
                selectedRows: selectedRows,
                coefficients: coefficients,
                iterations: iterations,
                converged: true
            )
        }
        guard iterations < options.maxIterations else {
            return try MaxVolResult(
                selectedRows: selectedRows,
                coefficients: coefficients,
                iterations: iterations,
                converged: false
            )
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

private func initialPivotRows<Scalar: MaxVolScalar>(
    for matrix: DenseColumnMajorMatrix<Scalar>
) throws -> [Int] {
    var factorization = matrix.values
    var rowCount = try lapackInt(matrix.rows)
    var columnCount = try lapackInt(matrix.columns)
    var leadingDimension = try lapackInt(matrix.leadingDimension)
    var pivots = Array(repeating: LAPACKInt(0), count: matrix.columns)
    var info = LAPACKInt(0)

    factorization.withUnsafeMutableBufferPointer { factorBuffer -> Void in
        pivots.withUnsafeMutableBufferPointer { pivotBuffer -> Void in
            Scalar.getrf(
                rowCount: &rowCount,
                columnCount: &columnCount,
                values: factorBuffer.baseAddress,
                leadingDimension: &leadingDimension,
                pivots: pivotBuffer.baseAddress,
                info: &info
            )
        }
    }

    try validateLapackInfo(info, routine: Scalar.getrfRoutineName, rankDeficientInfoIsPivot: true)

    var permutation = Array(0..<matrix.rows)
    for pivotIndex in 0..<matrix.columns {
        let swappedRow = Int(pivots[pivotIndex]) - 1
        permutation.swapAt(pivotIndex, swappedRow)
    }

    return Array(permutation.prefix(matrix.columns))
}

private func expansionCoefficients<Scalar: MaxVolScalar>(
    for matrix: DenseColumnMajorMatrix<Scalar>,
    selectedRows: [Int]
) throws -> DenseColumnMajorMatrix<Scalar> {
    let rank = selectedRows.count
    var basisValues = selectedRowsForBasis(matrix: matrix, selectedRows: selectedRows)
    var rowRankDimension = try lapackInt(rank)
    var columnRankDimension = try lapackInt(rank)
    var leadingDimension = try lapackInt(rank)
    var pivots = Array(repeating: LAPACKInt(0), count: rank)
    var info = LAPACKInt(0)

    basisValues.withUnsafeMutableBufferPointer { basisBuffer -> Void in
        pivots.withUnsafeMutableBufferPointer { pivotBuffer -> Void in
            Scalar.getrf(
                rowCount: &rowRankDimension,
                columnCount: &columnRankDimension,
                values: basisBuffer.baseAddress,
                leadingDimension: &leadingDimension,
                pivots: pivotBuffer.baseAddress,
                info: &info
            )
        }
    }

    try validateLapackInfo(info, routine: Scalar.getrfRoutineName, rankDeficientInfoIsPivot: true)
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
                Scalar.getrs(
                    transpose: &transpose,
                    dimension: &solveRankDimension,
                    rightHandSides: &rightHandSides,
                    factorization: basisBuffer.baseAddress,
                    leadingDimension: &basisLeadingDimension,
                    pivots: pivotBuffer.baseAddress,
                    rightHandSide: rightHandSideBuffer.baseAddress,
                    rightHandSideLeadingDimension: &rightHandSideLeadingDimension,
                    info: &info
                )
            }
        }
    }

    try validateLapackInfo(info, routine: Scalar.getrsRoutineName, rankDeficientInfoIsPivot: false)

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

private func selectedRowsForBasis<Scalar: MaxVolScalar>(
    matrix: DenseColumnMajorMatrix<Scalar>,
    selectedRows: [Int]
) -> [Scalar] {
    (0..<matrix.columns).flatMap { column in
        selectedRows.map { row in
            matrix[row: row, column: column]
        }
    }
}

private func transposedValues<Scalar: MaxVolScalar>(
    _ matrix: DenseColumnMajorMatrix<Scalar>
) -> [Scalar] {
    (0..<matrix.rows).flatMap { row in
        (0..<matrix.columns).map { column in
            matrix[row: row, column: column]
        }
    }
}

private func maximumMagnitude<Scalar: MaxVolScalar>(
    in coefficients: DenseColumnMajorMatrix<Scalar>
) -> CoefficientPivot {
    var pivot = CoefficientPivot(
        row: 0,
        column: 0,
        value: coefficients[row: 0, column: 0].magnitudeAsDouble
    )

    for column in 0..<coefficients.columns {
        for row in 0..<coefficients.rows {
            let magnitude = coefficients[row: row, column: column].magnitudeAsDouble
            if magnitude > pivot.value {
                pivot = CoefficientPivot(row: row, column: column, value: magnitude)
            }
        }
    }

    return pivot
}

private func replaceBasisRow<Scalar: MaxVolScalar>(
    pivotRow: Int,
    pivotColumn: Int,
    coefficients: inout DenseColumnMajorMatrix<Scalar>
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
                Scalar.rankOneUpdate(
                    rowCount: rowCount,
                    columnCount: columnCount,
                    alpha: -1,
                    x: columnBuffer.baseAddress,
                    incrementX: increment,
                    y: rowBuffer.baseAddress,
                    incrementY: increment,
                    values: coefficientBuffer.baseAddress,
                    leadingDimension: leadingDimension
                )
            }
        }
    }

    for row in 0..<coefficients.rows {
        coefficients[row: row, column: pivotColumn] += replacementColumn[row]
    }
}

private func validateNonsingularFactorization<Scalar: MaxVolScalar>(
    _ values: [Scalar],
    dimension: Int
) throws {
    let scale = max(values.map(\.magnitudeAsDouble).max() ?? 0, 1)
    let threshold = Scalar.rankToleranceUnit * Double(dimension) * scale

    for pivot in 0..<dimension {
        let diagonal = values[pivot * dimension + pivot]
        guard diagonal.magnitudeAsDouble > threshold else {
            throw MaxVolError.rankDeficient(pivot: pivot + 1)
        }
    }
}
