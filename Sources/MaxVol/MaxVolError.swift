public enum MaxVolError: Error, Equatable, Sendable {
    case invalidDimensions(rows: Int, columns: Int)
    case malformedMatrix(rows: Int, columns: Int, expectedCount: Int, actualCount: Int)
    case nonTallMatrix(rows: Int, columns: Int)
    case invalidSelectionCount(requested: Int, availableRows: Int)
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
            case let .nonTallMatrix(rows, columns):
                "MaxVol requires a tall or square input matrix with rows >= columns, but received rows: \(rows), columns: \(columns)."
            case let .invalidSelectionCount(requested, availableRows):
                "MaxVol cannot select \(requested) rows from a matrix with \(availableRows) available rows."
            case let .rankDeficient(pivot):
                "MaxVol could not continue because the input matrix appears rank-deficient at pivot \(pivot)."
            case let .lapackFailure(routine, info):
                "Accelerate LAPACK routine \(routine) reported info \(info)."
            case let .maximumIterationsExceeded(limit):
                "MaxVol stopped after reaching the maximum iteration limit of \(limit)."
        }
    }
}
