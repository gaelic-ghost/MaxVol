public enum MaxVolError: Error, Equatable, Sendable {
    case invalidDimensions(rows: Int, columns: Int)
    case malformedMatrix(rows: Int, columns: Int, expectedCount: Int, actualCount: Int)
    case matrixIndexOutOfBounds(row: Int, column: Int, rows: Int, columns: Int)
    case rowIndexOutOfBounds(row: Int, rows: Int)
    case columnIndexOutOfBounds(column: Int, columns: Int)
    case nonTallMatrix(rows: Int, columns: Int)
    case invalidSelectionCount(requested: Int, availableRows: Int)
    case invalidSelectedRowIndex(row: Int, availableRows: Int)
    case duplicateSelectedRow(row: Int)
    case coefficientColumnMismatch(selectedRows: Int, coefficientColumns: Int)
    case invalidTolerance(Double)
    case invalidIterationLimit(Int)
    case invalidIterationCount(Int)
    case rankDeficient(pivot: Int)
    case lapackFailure(routine: String, info: Int32)
    case maximumIterationsExceeded(limit: Int)
}

extension MaxVolError: CustomStringConvertible {
    public var description: String {
        switch self {
            case let .invalidDimensions(rows, columns):
                "MaxVol expected positive matrix dimensions, but received rows: \(rows), columns: \(columns)."
            case let .malformedMatrix(rows, columns, expectedCount, actualCount):
                "MaxVol expected \(expectedCount) values for a \(rows) x \(columns) dense matrix, but received \(actualCount)."
            case let .matrixIndexOutOfBounds(row, column, rows, columns):
                "MaxVol matrix index is out of bounds: row \(row), column \(column), valid row range 0..<\(rows), valid column range 0..<\(columns)."
            case let .rowIndexOutOfBounds(row, rows):
                "MaxVol matrix row index \(row) is out of bounds for valid row range 0..<\(rows)."
            case let .columnIndexOutOfBounds(column, columns):
                "MaxVol matrix column index \(column) is out of bounds for valid column range 0..<\(columns)."
            case let .nonTallMatrix(rows, columns):
                "MaxVol requires a tall or square input matrix with rows >= columns, but received rows: \(rows), columns: \(columns)."
            case let .invalidSelectionCount(requested, availableRows):
                "MaxVol cannot select \(requested) rows from a matrix with \(availableRows) available rows."
            case let .invalidSelectedRowIndex(row, availableRows):
                "MaxVol selected row index \(row) is out of bounds for a matrix with \(availableRows) rows."
            case let .duplicateSelectedRow(row):
                "MaxVol selected row index \(row) appears more than once, but selected rows must be unique."
            case let .coefficientColumnMismatch(selectedRows, coefficientColumns):
                "MaxVol result has \(selectedRows) selected rows but \(coefficientColumns) coefficient columns."
            case let .invalidTolerance(tolerance):
                "MaxVol tolerance must be finite and greater than 1.0, but received \(tolerance)."
            case let .invalidIterationLimit(limit):
                "MaxVol maximum iteration limit must be nonnegative, but received \(limit)."
            case let .invalidIterationCount(iterations):
                "MaxVol result cannot report a negative iteration count, but received \(iterations)."
            case let .rankDeficient(pivot):
                "MaxVol could not continue because the input matrix appears rank-deficient at pivot \(pivot)."
            case let .lapackFailure(routine, info):
                "Accelerate LAPACK routine \(routine) reported info \(info)."
            case let .maximumIterationsExceeded(limit):
                "MaxVol stopped after reaching the maximum iteration limit of \(limit)."
        }
    }
}
