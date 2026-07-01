/// Errors thrown by MaxVol matrix validation and Accelerate-backed computation.
public enum MaxVolError: Error, Equatable, Sendable {
    /// Matrix dimensions must be positive and fit in addressable storage.
    case invalidDimensions(rows: Int, columns: Int)

    /// The value buffer count does not match the requested matrix shape.
    case malformedMatrix(rows: Int, columns: Int, expectedCount: Int, actualCount: Int)

    /// A row and column pair is outside the matrix bounds.
    case matrixIndexOutOfBounds(row: Int, column: Int, rows: Int, columns: Int)

    /// A row index is outside the matrix bounds.
    case rowIndexOutOfBounds(row: Int, rows: Int)

    /// A column index is outside the matrix bounds.
    case columnIndexOutOfBounds(column: Int, columns: Int)

    /// MaxVol currently requires a tall or square input matrix.
    case nonTallMatrix(rows: Int, columns: Int)

    /// A requested selection count is incompatible with the available rows.
    case invalidSelectionCount(requested: Int, availableRows: Int)

    /// A selected row index is outside the input matrix bounds.
    case invalidSelectedRowIndex(row: Int, availableRows: Int)

    /// A result contains the same selected row more than once.
    case duplicateSelectedRow(row: Int)

    /// The result coefficient matrix does not match the selected row count.
    case coefficientColumnMismatch(selectedRows: Int, coefficientColumns: Int)

    /// The convergence tolerance is not finite or is less than `1.0`.
    case invalidTolerance(Double)

    /// The maximum iteration limit is negative.
    case invalidIterationLimit(Int)

    /// A result reports a negative iteration count.
    case invalidIterationCount(Int)

    /// The selected basis is rank-deficient.
    case rankDeficient(pivot: Int)

    /// An Accelerate LAPACK routine reported an unexpected nonzero `info` value.
    case lapackFailure(routine: String, info: Int)

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
                "MaxVol tolerance must be finite and at least 1.0, but received \(tolerance)."
            case let .invalidIterationLimit(limit):
                "MaxVol maximum iteration limit must be nonnegative, but received \(limit)."
            case let .invalidIterationCount(iterations):
                "MaxVol result cannot report a negative iteration count, but received \(iterations)."
            case let .rankDeficient(pivot):
                "MaxVol could not continue because the input matrix appears rank-deficient at pivot \(pivot)."
            case let .lapackFailure(routine, info):
                "Accelerate LAPACK routine \(routine) reported info \(info)."
        }
    }
}
