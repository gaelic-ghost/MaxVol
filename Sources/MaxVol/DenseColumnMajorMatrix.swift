/// A dense matrix stored in column-major order.
///
/// Column-major storage keeps values contiguous by column, matching the layout
/// expected by BLAS and LAPACK routines in Accelerate.
public struct DenseColumnMajorMatrix<Scalar: Sendable>: Sendable {
    /// The number of matrix rows.
    public let rows: Int

    /// The number of matrix columns.
    public let columns: Int

    /// The matrix values in column-major order.
    public internal(set) var values: [Scalar]

    /// The physical row stride between adjacent columns.
    public var leadingDimension: Int { rows }

    /// Creates a matrix from values that are already arranged by column.
    ///
    /// The value at `(row, column)` is stored at
    /// `column * leadingDimension + row`.
    public init(rows: Int, columns: Int, columnMajorValues values: [Scalar]) throws {
        try Self.validateDimensions(rows: rows, columns: columns)
        try Self.validateValueCount(rows: rows, columns: columns, valueCount: values.count)

        self.rows = rows
        self.columns = columns
        self.values = values
    }

    /// Creates a matrix from values arranged by row.
    ///
    /// The initializer converts the input into column-major storage so the
    /// resulting matrix can be passed directly to Accelerate-backed routines.
    public init(rows: Int, columns: Int, rowMajorValues values: [Scalar]) throws {
        try Self.validateDimensions(rows: rows, columns: columns)
        try Self.validateValueCount(rows: rows, columns: columns, valueCount: values.count)

        self.rows = rows
        self.columns = columns
        self.values = (0..<columns).flatMap { column in
            (0..<rows).map { row in
                values[row * columns + column]
            }
        }
    }

    private static func validateDimensions(rows: Int, columns: Int) throws {
        guard rows > 0, columns > 0 else {
            throw MaxVolError.invalidDimensions(rows: rows, columns: columns)
        }
        guard !rows.multipliedReportingOverflow(by: columns).overflow else {
            throw MaxVolError.invalidDimensions(rows: rows, columns: columns)
        }
    }

    private static func validateValueCount(rows: Int, columns: Int, valueCount: Int) throws {
        let expectedCount = rows * columns
        guard valueCount == expectedCount else {
            throw MaxVolError.malformedMatrix(
                rows: rows,
                columns: columns,
                expectedCount: expectedCount,
                actualCount: valueCount
            )
        }
    }

    /// Returns the value at a checked row and column index.
    public func value(row: Int, column: Int) throws -> Scalar {
        try validateIndex(row: row, column: column)
        return self[row: row, column: column]
    }

    /// Replaces the value at a checked row and column index.
    public mutating func setValue(_ value: Scalar, row: Int, column: Int) throws {
        try validateIndex(row: row, column: column)
        self[row: row, column: column] = value
    }

    /// Returns the values in a checked row index.
    public func row(_ row: Int) throws -> [Scalar] {
        try validateRow(row)
        return (0..<columns).map { column in
            self[row: row, column: column]
        }
    }

    /// Returns a contiguous slice for a checked column index.
    public func column(_ column: Int) throws -> ArraySlice<Scalar> {
        try validateColumn(column)
        let start = column * leadingDimension
        return values[start..<start + rows]
    }

    /// Returns the matrix after checking that it has at least as many rows as columns.
    public func validatedTallMatrix() throws -> Self {
        guard rows >= columns else {
            throw MaxVolError.nonTallMatrix(rows: rows, columns: columns)
        }

        return self
    }

    subscript(row row: Int, column column: Int) -> Scalar {
        get { values[column * leadingDimension + row] }
        set { values[column * leadingDimension + row] = newValue }
    }

    private func validateIndex(row: Int, column: Int) throws {
        guard (0..<rows).contains(row), (0..<columns).contains(column) else {
            throw MaxVolError.matrixIndexOutOfBounds(
                row: row,
                column: column,
                rows: rows,
                columns: columns
            )
        }
    }

    private func validateRow(_ row: Int) throws {
        guard (0..<rows).contains(row) else {
            throw MaxVolError.rowIndexOutOfBounds(row: row, rows: rows)
        }
    }

    private func validateColumn(_ column: Int) throws {
        guard (0..<columns).contains(column) else {
            throw MaxVolError.columnIndexOutOfBounds(column: column, columns: columns)
        }
    }
}

extension DenseColumnMajorMatrix: Equatable where Scalar: Equatable {}
extension DenseColumnMajorMatrix: Hashable where Scalar: Hashable {}
