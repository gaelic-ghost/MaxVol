@testable import MaxVol
import Testing

struct DenseColumnMajorMatrixTests {
    @Test func rowMajorInitializerStoresValuesInColumnMajorOrder() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 3,
            rowMajorValues: [
                1, 2, 3,
                4, 5, 6,
            ]
        )

        #expect(matrix.rows == 2)
        #expect(matrix.columns == 3)
        #expect(matrix.leadingDimension == 2)
        #expect(matrix.values == [1, 4, 2, 5, 3, 6])
        #expect(matrix[row: 1, column: 2] == 6)
    }

    @Test func columnMajorInitializerPreservesStorageOrder() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 3,
            columns: 2,
            columnMajorValues: [
                1, 2, 3,
                4, 5, 6,
            ]
        )

        #expect(matrix.values == [1, 2, 3, 4, 5, 6])
        #expect(matrix.row(1) == [2, 5])
        #expect(Array(matrix.column(1)) == [4, 5, 6])
    }

    @Test func initializerRejectsNonPositiveDimensions() throws {
        #expect(throws: MaxVolError.invalidDimensions(rows: 0, columns: 2)) {
            try DenseColumnMajorMatrix(
                rows: 0,
                columns: 2,
                columnMajorValues: [Double]()
            )
        }
    }

    @Test func initializerRejectsMalformedValueCount() throws {
        #expect(
            throws: MaxVolError.malformedMatrix(
                rows: 2,
                columns: 3,
                expectedCount: 6,
                actualCount: 5
            )
        ) {
            try DenseColumnMajorMatrix(
                rows: 2,
                columns: 3,
                columnMajorValues: [1, 2, 3, 4, 5]
            )
        }
    }

    @Test func tallMatrixValidationRejectsWideInputs() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 3,
            rowMajorValues: [
                1, 2, 3,
                4, 5, 6,
            ]
        )

        #expect(throws: MaxVolError.nonTallMatrix(rows: 2, columns: 3)) {
            try matrix.validatedTallMatrix()
        }
    }

    @Test func resultStoresSelectedRowsCoefficientsAndIterations() throws {
        let coefficients = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 2,
            columnMajorValues: [
                1, 0,
                0, 1,
            ]
        )
        let result = MaxVolResult(
            selectedRows: [0, 2],
            coefficients: coefficients,
            iterations: 3
        )

        #expect(result.selectedRows == [0, 2])
        #expect(result.coefficients == coefficients)
        #expect(result.iterations == 3)
    }
}
