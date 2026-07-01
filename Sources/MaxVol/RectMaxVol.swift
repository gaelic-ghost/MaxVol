/// Selects a high-volume rectangular row basis from a tall dense `Double` matrix.
///
/// RectMaxVol starts with ``maxVol(_:options:)->MaxVolResult<Double>`` and appends
/// rows until every remaining unselected coefficient row satisfies
/// ``RectMaxVolOptions/tolerance`` or the configured row bounds stop the append loop.
public func rectMaxVol(
    _ matrix: DenseColumnMajorMatrix<Double>,
    options: RectMaxVolOptions = RectMaxVolOptions()
) throws -> MaxVolResult<Double> {
    try rectMaxVolImpl(matrix, options: options)
}

/// Selects a high-volume rectangular row basis from a tall dense `Float` matrix.
///
/// RectMaxVol starts with ``maxVol(_:options:)->MaxVolResult<Float>`` and appends
/// rows until every remaining unselected coefficient row satisfies
/// ``RectMaxVolOptions/tolerance`` or the configured row bounds stop the append loop.
public func rectMaxVol(
    _ matrix: DenseColumnMajorMatrix<Float>,
    options: RectMaxVolOptions = RectMaxVolOptions()
) throws -> MaxVolResult<Float> {
    try rectMaxVolImpl(matrix, options: options)
}

func rectMaxVolImpl<Scalar: MaxVolScalar>(
    _ matrix: DenseColumnMajorMatrix<Scalar>,
    options: RectMaxVolOptions = RectMaxVolOptions()
) throws -> MaxVolResult<Scalar> {
    let input = try matrix.validatedTallMatrix()
    let options = try options.resolved(rows: input.rows, columns: input.columns)
    let initial = try maxVolImpl(
        input,
        options: MaxVolOptions(maxIterations: options.startMaxVolIterations)
    )
    var selectedRows = initial.selectedRows
    var coefficients = initial.coefficients
    var iterations = 0

    while true {
        let candidate = maximumUnselectedRowNormSquared(
            in: coefficients,
            selectedRows: selectedRows
        )
        let toleranceNeedsAppend = candidate.value > options.toleranceSquared
            && selectedRows.count < options.maxRows
        let minimumNeedsAppend = selectedRows.count < options.minRows

        guard toleranceNeedsAppend || minimumNeedsAppend else {
            let output = try coefficientsWithIdentityRows(
                coefficients,
                selectedRows: selectedRows
            )
            return try MaxVolResult(
                selectedRows: selectedRows,
                coefficients: output,
                iterations: iterations,
                converged: candidate.value <= options.toleranceSquared || selectedRows.count == input.rows
            )
        }
        guard let candidateRow = candidate.row, selectedRows.count < options.maxRows else {
            let output = try coefficientsWithIdentityRows(
                coefficients,
                selectedRows: selectedRows
            )
            return try MaxVolResult(
                selectedRows: selectedRows,
                coefficients: output,
                iterations: iterations,
                converged: false
            )
        }

        coefficients = try appendRectangularBasisRow(
            candidateRow,
            to: coefficients
        )
        selectedRows.append(candidateRow)
        iterations += 1
    }
}

private struct RowNormCandidate {
    let row: Int?
    let value: Double
}

private func maximumUnselectedRowNormSquared<Scalar: MaxVolScalar>(
    in coefficients: DenseColumnMajorMatrix<Scalar>,
    selectedRows: [Int]
) -> RowNormCandidate {
    let selected = Set(selectedRows)
    var candidate = RowNormCandidate(row: nil, value: 0)

    for row in 0..<coefficients.rows where !selected.contains(row) {
        let value = (0..<coefficients.columns).reduce(0) { total, column in
            let coefficient = coefficients[row: row, column: column]
            return total + coefficient.magnitudeAsDouble * coefficient.magnitudeAsDouble
        }

        if candidate.row == nil || value > candidate.value {
            candidate = RowNormCandidate(row: row, value: value)
        }
    }

    return candidate
}

private func appendRectangularBasisRow<Scalar: MaxVolScalar>(
    _ candidateRow: Int,
    to coefficients: DenseColumnMajorMatrix<Scalar>
) throws -> DenseColumnMajorMatrix<Scalar> {
    let candidateCoefficients = try coefficients.row(candidateRow)
    let projection = (0..<coefficients.rows).map { row in
        (0..<coefficients.columns).reduce(Scalar.zero) { total, column in
            total + coefficients[row: row, column: column] * candidateCoefficients[column]
        }
    }
    let scale = 1 / (1 + projection[candidateRow])
    let appendedColumn = projection.map { scale * $0 }
    var updatedValues = coefficients.values
    let rowCount = try lapackInt(coefficients.rows)
    let columnCount = try lapackInt(coefficients.columns)
    let increment = LAPACKInt(1)
    let leadingDimension = try lapackInt(coefficients.leadingDimension)

    projection.withUnsafeBufferPointer { projectionBuffer -> Void in
        candidateCoefficients.withUnsafeBufferPointer { coefficientBuffer -> Void in
            updatedValues.withUnsafeMutableBufferPointer { updatedBuffer -> Void in
                Scalar.rankOneUpdate(
                    rowCount: rowCount,
                    columnCount: columnCount,
                    alpha: -scale,
                    x: projectionBuffer.baseAddress,
                    incrementX: increment,
                    y: coefficientBuffer.baseAddress,
                    incrementY: increment,
                    values: updatedBuffer.baseAddress,
                    leadingDimension: leadingDimension
                )
            }
        }
    }

    updatedValues.append(contentsOf: appendedColumn)
    return try DenseColumnMajorMatrix(
        rows: coefficients.rows,
        columns: coefficients.columns + 1,
        columnMajorValues: updatedValues
    )
}

private func coefficientsWithIdentityRows<Scalar: MaxVolScalar>(
    _ coefficients: DenseColumnMajorMatrix<Scalar>,
    selectedRows: [Int]
) throws -> DenseColumnMajorMatrix<Scalar> {
    var output = coefficients

    for (identityColumn, selectedRow) in selectedRows.enumerated() {
        for column in 0..<output.columns {
            try output.setValue(
                column == identityColumn ? 1 : 0,
                row: selectedRow,
                column: column
            )
        }
    }

    return output
}
