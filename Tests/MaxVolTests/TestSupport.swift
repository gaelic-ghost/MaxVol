@testable import MaxVol
import Testing

func expectReconstruction(
    of matrix: DenseColumnMajorMatrix<Double>,
    using result: MaxVolResult<Double>,
    tolerance: Double = 1e-10
) throws {
    for row in 0..<matrix.rows {
        for column in 0..<matrix.columns {
            var reconstructed = 0.0
            for selectedColumn in 0..<result.selectedRows.count {
                reconstructed += try result.coefficients.value(row: row, column: selectedColumn)
                    * matrix.value(row: result.selectedRows[selectedColumn], column: column)
            }

            let expected = try matrix.value(row: row, column: column)
            #expect(abs(reconstructed - expected) <= tolerance)
        }
    }
}

func expectReconstruction(
    of matrix: DenseColumnMajorMatrix<Float>,
    using result: MaxVolResult<Float>,
    tolerance: Float = 1e-5
) throws {
    for row in 0..<matrix.rows {
        for column in 0..<matrix.columns {
            var reconstructed: Float = 0
            for selectedColumn in 0..<result.selectedRows.count {
                reconstructed += try result.coefficients.value(row: row, column: selectedColumn)
                    * matrix.value(row: result.selectedRows[selectedColumn], column: column)
            }

            let expected = try matrix.value(row: row, column: column)
            #expect(abs(reconstructed - expected) <= tolerance)
        }
    }
}

func expectCoefficients(
    _ coefficients: DenseColumnMajorMatrix<Double>,
    rowMajorValues: [Double],
    tolerance: Double = 1e-12
) throws {
    let expected = try DenseColumnMajorMatrix(
        rows: coefficients.rows,
        columns: coefficients.columns,
        rowMajorValues: rowMajorValues
    )

    for row in 0..<coefficients.rows {
        for column in 0..<coefficients.columns {
            let actualValue = try coefficients.value(row: row, column: column)
            let expectedValue = try expected.value(row: row, column: column)
            #expect(abs(actualValue - expectedValue) <= tolerance)
        }
    }
}

func expectCoefficients(
    _ coefficients: DenseColumnMajorMatrix<Float>,
    rowMajorValues: [Float],
    tolerance: Float = 5e-6
) throws {
    let expected = try DenseColumnMajorMatrix(
        rows: coefficients.rows,
        columns: coefficients.columns,
        rowMajorValues: rowMajorValues
    )

    for row in 0..<coefficients.rows {
        for column in 0..<coefficients.columns {
            let actualValue = try coefficients.value(row: row, column: column)
            let expectedValue = try expected.value(row: row, column: column)
            #expect(abs(actualValue - expectedValue) <= tolerance)
        }
    }
}

func expectSelectedRowsAreIdentity(
    _ result: MaxVolResult<Double>,
    tolerance: Double = 1e-12
) throws {
    for (identityColumn, selectedRow) in result.selectedRows.enumerated() {
        for column in 0..<result.coefficients.columns {
            let expected = column == identityColumn ? 1.0 : 0.0
            let actual = try result.coefficients.value(row: selectedRow, column: column)
            #expect(abs(actual - expected) <= tolerance)
        }
    }
}

func expectSelectedRowsAreIdentity(
    _ result: MaxVolResult<Float>,
    tolerance: Float = 1e-6
) throws {
    for (identityColumn, selectedRow) in result.selectedRows.enumerated() {
        for column in 0..<result.coefficients.columns {
            let expected: Float = column == identityColumn ? 1 : 0
            let actual = try result.coefficients.value(row: selectedRow, column: column)
            #expect(abs(actual - expected) <= tolerance)
        }
    }
}

func maximumAbsoluteCoefficient(
    in coefficients: DenseColumnMajorMatrix<Double>
) -> Double {
    coefficients.values.map(abs).max() ?? 0
}

func maximumAbsoluteCoefficient(
    in coefficients: DenseColumnMajorMatrix<Float>
) -> Double {
    coefficients.values.map { Double(abs($0)) }.max() ?? 0
}

func maximumUnselectedRowNorm(in result: MaxVolResult<Double>) -> Double {
    let selected = Set(result.selectedRows)
    return (0..<result.coefficients.rows)
        .filter { !selected.contains($0) }
        .map { row in
            let normSquared = (0..<result.coefficients.columns).reduce(0.0) { total, column in
                let coefficient = result.coefficients[row: row, column: column]
                return total + coefficient * coefficient
            }
            return normSquared.squareRoot()
        }
        .max() ?? 0
}

func maximumUnselectedRowNorm(in result: MaxVolResult<Float>) -> Double {
    let selected = Set(result.selectedRows)
    return (0..<result.coefficients.rows)
        .filter { !selected.contains($0) }
        .map { row in
            let normSquared = (0..<result.coefficients.columns).reduce(0.0) { total, column in
                let coefficient = Double(result.coefficients[row: row, column: column])
                return total + coefficient * coefficient
            }
            return normSquared.squareRoot()
        }
        .max() ?? 0
}

func orthonormalColumns(
    rows: Int,
    columns: Int,
    seed: UInt64
) throws -> DenseColumnMajorMatrix<Double> {
    var generator = SeededGenerator(state: seed)
    var columnVectors = (0..<columns).map { column -> [Double] in
        (0..<rows).map { row in
            generator.nextDouble() + (row == column ? 1.0 : 0.0)
        }
    }

    for column in 0..<columns {
        for priorColumn in 0..<column {
            let projection = dot(columnVectors[column], columnVectors[priorColumn])
            for row in 0..<rows {
                columnVectors[column][row] -= projection * columnVectors[priorColumn][row]
            }
        }

        let norm = dot(columnVectors[column], columnVectors[column]).squareRoot()
        for row in 0..<rows {
            columnVectors[column][row] /= norm
        }
    }

    return try DenseColumnMajorMatrix(
        rows: rows,
        columns: columns,
        columnMajorValues: columnVectors.flatMap { $0 }
    )
}

func dot(_ left: [Double], _ right: [Double]) -> Double {
    zip(left, right).reduce(0) { total, pair in
        total + pair.0 * pair.1
    }
}

struct SeededGenerator {
    var state: UInt64

    mutating func nextDouble() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let scaled = Double(state >> 11) / Double(UInt64.max >> 11)
        return scaled * 2 - 1
    }
}

extension DenseColumnMajorMatrix where Scalar == Double {
    func mapValues<Output: Sendable>(
        _ transform: (Double) -> Output
    ) throws -> DenseColumnMajorMatrix<Output> {
        try DenseColumnMajorMatrix<Output>(
            rows: rows,
            columns: columns,
            columnMajorValues: values.map(transform)
        )
    }
}
