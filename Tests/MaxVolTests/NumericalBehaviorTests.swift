@testable import MaxVol
import Testing

struct NumericalBehaviorTests {
    @Test func randomizedOrthonormalMatricesSatisfyDoubleCriteriaAcrossSizes() throws {
        for (rows, columns, seed) in [
            (8, 3, UInt64(0xD011_0001)),
            (13, 4, UInt64(0xD011_0002)),
            (21, 6, UInt64(0xD011_0003)),
        ] {
            let matrix = try orthonormalColumns(rows: rows, columns: columns, seed: seed)

            let square = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 200))
            #expect(square.selectedRows.count == matrix.columns)
            #expect(square.converged)
            #expect(maximumAbsoluteCoefficient(in: square.coefficients) <= 1.05)
            try expectReconstruction(of: matrix, using: square, tolerance: 1e-9)

            let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 1.0))
            #expect(rectangular.selectedRows.count >= matrix.columns)
            #expect(rectangular.converged)
            #expect(maximumUnselectedRowNorm(in: rectangular) <= 1.0 + 1e-12)
            try expectReconstruction(of: matrix, using: rectangular, tolerance: 1e-9)
        }
    }

    @Test func randomizedOrthonormalMatricesSatisfyFloatCriteriaAcrossSizes() throws {
        for (rows, columns, seed) in [
            (8, 3, UInt64(0xF10A_0001)),
            (13, 4, UInt64(0xF10A_0002)),
            (21, 6, UInt64(0xF10A_0003)),
        ] {
            let matrix = try orthonormalColumns(rows: rows, columns: columns, seed: seed).mapValues(Float.init)

            let square = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 200))
            #expect(square.selectedRows.count == matrix.columns)
            #expect(square.converged)
            #expect(maximumAbsoluteCoefficient(in: square.coefficients) <= 1.05 + 1e-6)
            try expectReconstruction(of: matrix, using: square, tolerance: 5e-5)

            let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 1.0))
            #expect(rectangular.selectedRows.count >= matrix.columns)
            #expect(rectangular.converged)
            #expect(maximumUnselectedRowNorm(in: rectangular) <= 1.0 + 1e-5)
            try expectReconstruction(of: matrix, using: rectangular, tolerance: 5e-5)
        }
    }

    @Test func nearRankDeficientDoubleAndFloatInputsThrowDescriptiveErrors() throws {
        let doubleMatrix = try DenseColumnMajorMatrix<Double>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                1.0, 1.0,
                2.0, 2.0 + Double.ulpOfOne / 16,
                3.0, 3.0,
            ]
        )
        let floatMatrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                1.0, 1.0,
                2.0, 2.0 + Float.ulpOfOne / 16,
                3.0, 3.0,
            ]
        )

        #expect(throws: MaxVolError.rankDeficient(pivot: 2)) {
            try maxVol(doubleMatrix)
        }
        #expect(throws: MaxVolError.rankDeficient(pivot: 2)) {
            try maxVol(floatMatrix)
        }
    }
}

private func expectReconstruction(
    of matrix: DenseColumnMajorMatrix<Double>,
    using result: MaxVolResult<Double>,
    tolerance: Double
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

private func expectReconstruction(
    of matrix: DenseColumnMajorMatrix<Float>,
    using result: MaxVolResult<Float>,
    tolerance: Float
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

private func maximumAbsoluteCoefficient(
    in coefficients: DenseColumnMajorMatrix<Double>
) -> Double {
    coefficients.values.map(abs).max() ?? 0
}

private func maximumAbsoluteCoefficient(
    in coefficients: DenseColumnMajorMatrix<Float>
) -> Double {
    coefficients.values.map { Double(abs($0)) }.max() ?? 0
}

private func maximumUnselectedRowNorm(in result: MaxVolResult<Double>) -> Double {
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

private func maximumUnselectedRowNorm(in result: MaxVolResult<Float>) -> Double {
    let selected = Set(result.selectedRows)
    return (0..<result.coefficients.rows)
        .filter { !selected.contains($0) }
        .map { row in
            let normSquared = (0..<result.coefficients.columns).reduce(0.0) { total, column in
                let coefficient = result.coefficients[row: row, column: column]
                return total + Double(coefficient * coefficient)
            }
            return normSquared.squareRoot()
        }
        .max() ?? 0
}

private func orthonormalColumns(
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

private func dot(_ left: [Double], _ right: [Double]) -> Double {
    zip(left, right).reduce(0) { total, pair in
        total + pair.0 * pair.1
    }
}

private struct SeededGenerator {
    var state: UInt64

    mutating func nextDouble() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let scaled = Double(state >> 11) / Double(UInt64.max >> 11)
        return scaled * 2 - 1
    }
}

private extension DenseColumnMajorMatrix where Scalar == Double {
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
