@testable import MaxVol
import Testing

struct MaxVolAlgorithmTests {
    // Reference fixture values in this suite were generated with
    // maxvolpy.maxvol.py_maxvol running on NumPy/SciPy.

    @Test func squareIdentityReturnsIdentityCoefficients() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 2,
            rowMajorValues: [
                1.0, 0.0,
                0.0, 1.0,
            ]
        )

        let result = try maxVol(matrix)

        #expect(result.selectedRows == [0, 1])
        #expect(result.iterations == 0)
        #expect(result.converged)
        try expectReconstruction(of: matrix, using: result)
    }

    @Test func maxVolPyReferenceFixtureMatchesPivotsAndCoefficients() throws {
        let matrix = try DenseColumnMajorMatrix(
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
                2.0 / 3.0, 2.0 / 3.0,
                1.0, 0.0,
            ]
        )
        #expect(maximumAbsoluteCoefficient(in: result.coefficients) == 1.0)
        try expectReconstruction(of: matrix, using: result)
    }

    @Test func zeroMaxIterationsReturnsInitialLUReferenceFixture() throws {
        let matrix = try DenseColumnMajorMatrix(
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

    @Test func iterationLimitReturnsPartialReferenceFixture() throws {
        let matrix = try DenseColumnMajorMatrix(
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
                2.0 / 3.0, 2.0 / 3.0,
                1.0 / 3.0, 4.0 / 3.0,
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
                -0.25, 0.75,
                0.5, 0.5,
                0.0, 1.0,
                1.0, 0.0,
            ]
        )
        #expect(maximumAbsoluteCoefficient(in: converged.coefficients) == 1.0)
        try expectReconstruction(of: matrix, using: converged)
    }

    @Test func rankDeficientInputThrowsDescriptiveError() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                1.0, 2.0,
                2.0, 4.0,
                3.0, 6.0,
            ]
        )

        #expect(throws: MaxVolError.rankDeficient(pivot: 2)) {
            try maxVol(matrix)
        }
    }

    @Test func nonTallInputIsRejectedBeforeAccelerateCalls() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 3,
            rowMajorValues: [
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
            ]
        )

        #expect(throws: MaxVolError.nonTallMatrix(rows: 2, columns: 3)) {
            try maxVol(matrix)
        }
    }

    @Test func invalidOptionsAreRejected() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 2,
            rowMajorValues: [
                1.0, 0.0,
                0.0, 1.0,
            ]
        )

        #expect(throws: MaxVolError.invalidTolerance(0.999)) {
            try maxVol(matrix, options: MaxVolOptions(tolerance: 0.999))
        }
        #expect(throws: MaxVolError.invalidTolerance(.infinity)) {
            try maxVol(matrix, options: MaxVolOptions(tolerance: .infinity))
        }
        #expect(throws: MaxVolError.invalidIterationLimit(-1)) {
            try maxVol(matrix, options: MaxVolOptions(maxIterations: -1))
        }
    }

    private func expectReconstruction(
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

    private func expectCoefficients(
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

    private func maximumAbsoluteCoefficient(
        in coefficients: DenseColumnMajorMatrix<Double>
    ) -> Double {
        coefficients.values.map(abs).max() ?? 0
    }
}
