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
        #expect(try matrix.value(row: 1, column: 2) == 6)
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
        #expect(try matrix.row(1) == [2, 5])
        #expect(try Array(matrix.column(1)) == [4, 5, 6])
    }

    @Test func checkedValueAccessRejectsOutOfBoundsIndex() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 2,
            columnMajorValues: [
                1, 2,
                3, 4,
            ]
        )

        #expect(
            throws: MaxVolError.matrixIndexOutOfBounds(
                row: 2,
                column: 1,
                rows: 2,
                columns: 2
            )
        ) {
            try matrix.value(row: 2, column: 1)
        }
    }

    @Test func checkedRowAndColumnAccessRejectOutOfBoundsIndices() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 2,
            columnMajorValues: [
                1, 2,
                3, 4,
            ]
        )

        #expect(throws: MaxVolError.rowIndexOutOfBounds(row: -1, rows: 2)) {
            try matrix.row(-1)
        }
        #expect(throws: MaxVolError.columnIndexOutOfBounds(column: 2, columns: 2)) {
            try matrix.column(2)
        }
    }

    @Test func checkedMutationUpdatesStoredValue() throws {
        var matrix = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 2,
            columnMajorValues: [
                1, 2,
                3, 4,
            ]
        )

        try matrix.setValue(9, row: 1, column: 0)

        #expect(matrix.values == [1, 9, 3, 4])
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
        let result = try MaxVolResult(
            selectedRows: [0, 1],
            coefficients: coefficients,
            iterations: 3
        )

        #expect(result.selectedRows == [0, 1])
        #expect(result.coefficients == coefficients)
        #expect(result.iterations == 3)
        #expect(result.converged)
    }

    @Test func resultRejectsNegativeIterationCount() throws {
        let coefficients = try DenseColumnMajorMatrix(
            rows: 2,
            columns: 2,
            columnMajorValues: [
                1, 0,
                0, 1,
            ]
        )

        #expect(throws: MaxVolError.invalidIterationCount(-1)) {
            try MaxVolResult(
                selectedRows: [0, 1],
                coefficients: coefficients,
                iterations: -1
            )
        }
    }

    @Test func resultRejectsCoefficientColumnMismatch() throws {
        let coefficients = try DenseColumnMajorMatrix(
            rows: 3,
            columns: 2,
            columnMajorValues: [
                1, 0, 0,
                0, 1, 0,
            ]
        )

        #expect(
            throws: MaxVolError.coefficientColumnMismatch(
                selectedRows: 1,
                coefficientColumns: 2
            )
        ) {
            try MaxVolResult(
                selectedRows: [0],
                coefficients: coefficients,
                iterations: 0
            )
        }
    }

    @Test func resultRejectsInvalidAndDuplicateSelectedRows() throws {
        let coefficients = try DenseColumnMajorMatrix(
            rows: 3,
            columns: 2,
            columnMajorValues: [
                1, 0, 0,
                0, 1, 0,
            ]
        )

        #expect(throws: MaxVolError.invalidSelectedRowIndex(row: 3, availableRows: 3)) {
            try MaxVolResult(
                selectedRows: [0, 3],
                coefficients: coefficients,
                iterations: 0
            )
        }
        #expect(throws: MaxVolError.duplicateSelectedRow(row: 1)) {
            try MaxVolResult(
                selectedRows: [1, 1],
                coefficients: coefficients,
                iterations: 0
            )
        }
    }
}
