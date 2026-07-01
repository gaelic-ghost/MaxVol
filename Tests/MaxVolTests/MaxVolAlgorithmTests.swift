@testable import MaxVol
import Testing

struct MaxVolAlgorithmTests {
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
        try expectReconstruction(of: matrix, using: result)
    }

    @Test func stableTallMatrixReconstructsFromSelectedRows() throws {
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

        let result = try maxVol(matrix)

        #expect(result.selectedRows.count == matrix.columns)
        #expect(Set(result.selectedRows).count == result.selectedRows.count)
        #expect(result.selectedRows.allSatisfy { (0..<matrix.rows).contains($0) })
        try expectReconstruction(of: matrix, using: result)
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

        #expect(throws: MaxVolError.invalidTolerance(1)) {
            try maxVol(matrix, options: MaxVolOptions(tolerance: 1))
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
}
