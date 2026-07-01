@testable import MaxVol
import Testing

struct FloatMaxVolTests {
    // Reference fixture values in this suite were generated with
    // maxvolpy.maxvol.py_maxvol and py_rect_maxvol running on NumPy/SciPy
    // with np.float32 inputs.

    @Test func squareReferenceFixtureMatchesFloat32PivotsAndCoefficients() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.0))

        #expect(result.selectedRows == [2, 0])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                0.666_666_626_930_236_8, 0.666_666_686_534_881_6,
                1.0, 0.0,
            ]
        )
        #expect(maximumAbsoluteCoefficient(in: result.coefficients) == 1.0)
        try expectReconstruction(of: matrix, using: result)
    }

    @Test func zeroMaxIterationsReturnsFloat32InitialLUFixture() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try maxVol(matrix, options: MaxVolOptions(maxIterations: 0))

        #expect(result.selectedRows == [1, 0])
        #expect(result.iterations == 0)
        #expect(!result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                1.0, 0.0,
                1.5, -1.0,
            ]
        )
        #expect(maximumAbsoluteCoefficient(in: result.coefficients) == 1.5)
        try expectReconstruction(of: matrix, using: result)
    }

    @Test func iterationLimitReturnsFloat32PartialFixture() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 4,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 0.5,
                0.5, 1.5,
            ]
        )

        let limited = try maxVol(matrix, options: MaxVolOptions(maxIterations: 1))
        let converged = try maxVol(matrix, options: MaxVolOptions(maxIterations: 2))

        #expect(limited.selectedRows == [3, 0])
        #expect(limited.iterations == 1)
        #expect(!limited.converged)
        try expectCoefficients(
            limited.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                0.666_666_626_930_236_8, 0.666_666_686_534_881_6,
                0.333_333_313_465_118_4, 1.333_333_373_069_763_2,
                1.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: limited)

        #expect(converged.selectedRows == [3, 2])
        #expect(converged.iterations == 2)
        #expect(converged.converged)
        try expectCoefficients(
            converged.coefficients,
            rowMajorValues: [
                -0.249_999_985_098_838_8, 0.75,
                0.499_999_970_197_677_6, 0.5,
                0.0, 1.0,
                1.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: converged)
    }

    @Test func rectangularReferenceFixtureAppendsRequiredMinimumRows() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 4,
            columns: 2,
            rowMajorValues: [
                1.0, 0.0,
                0.0, 1.0,
                0.5, 0.25,
                -0.25, 0.75,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(minRows: 3))

        #expect(result.selectedRows == [0, 1, 3])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.509_615_361_690_521_2, 0.221_153_840_422_630_3, 0.038_461_539_894_342_42,
                0.0, 0.0, 1.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
    }

    @Test func rectangularReferenceFixtureRespectsMaximumRowsLimit() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 0.9, maxRows: 2))

        #expect(result.selectedRows == [2, 0])
        #expect(result.iterations == 0)
        #expect(!result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                0.666_666_626_930_236_8, 0.666_666_686_534_881_6,
                1.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        #expect(maximumUnselectedRowNorm(in: result) > 0.9)
    }

    @Test func rectangularReferenceFixtureSelectsAllRowsWhenNeeded() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 0.9, maxRows: 3))

        #expect(result.selectedRows == [2, 0, 1])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0, 0.0,
                0.0, 0.0, 1.0,
                1.0, 0.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
    }

    @Test func rectangularReferenceFixtureMatchesAppendCase() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 5,
            columns: 2,
            rowMajorValues: [
                1.0, 0.0,
                0.0, 1.0,
                1.2, 0.2,
                0.1, 1.3,
                0.8, 0.8,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(minRows: 3))

        #expect(result.selectedRows == [2, 3, 0])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 0.0, 1.0,
                0.011_215_145_699_679_852, 0.767_505_407_333_374, -0.090_208_716_690_540_31,
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.399_453_848_600_387_6, 0.553_930_222_988_128_7, 0.265_262_335_538_864_14,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
        #expect(maximumUnselectedRowNorm(in: result) <= 1.0)
    }

    @Test func randomizedOrthonormalTallMatrixSatisfiesFloatCriteria() throws {
        let matrix = try orthonormalColumns(rows: 14, columns: 5, seed: 0xF10A7).mapValues(Float.init)

        let square = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 100))
        #expect(square.selectedRows.count == matrix.columns)
        #expect(square.converged)
        #expect(maximumAbsoluteCoefficient(in: square.coefficients) <= 1.05 + 1e-6)
        try expectReconstruction(of: matrix, using: square, tolerance: 5e-5)

        let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 1.0))
        #expect(rectangular.selectedRows.count >= matrix.columns)
        #expect(rectangular.converged)
        #expect(maximumUnselectedRowNorm(in: rectangular) <= 1.0 + 1e-5)
        try expectReconstruction(of: matrix, using: rectangular, tolerance: 5e-5)
        try expectSelectedRowsAreIdentity(rectangular)
    }

    @Test func nearRankDeficientFloatInputThrowsDescriptiveError() throws {
        let epsilon = Float.ulpOfOne / 16
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                1.0, 1.0,
                2.0, 2.0 + epsilon,
                3.0, 3.0,
            ]
        )

        #expect(throws: MaxVolError.rankDeficient(pivot: 2)) {
            try maxVol(matrix)
        }
    }
}

private func expectReconstruction(
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

private func expectCoefficients(
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

private func expectSelectedRowsAreIdentity(_ result: MaxVolResult<Float>) throws {
    for (identityColumn, selectedRow) in result.selectedRows.enumerated() {
        for column in 0..<result.coefficients.columns {
            let expected: Float = column == identityColumn ? 1 : 0
            let actual = try result.coefficients.value(row: selectedRow, column: column)
            #expect(abs(actual - expected) <= 1e-6)
        }
    }
}

private func maximumAbsoluteCoefficient(
    in coefficients: DenseColumnMajorMatrix<Float>
) -> Double {
    coefficients.values.map { Double(abs($0)) }.max() ?? 0
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
