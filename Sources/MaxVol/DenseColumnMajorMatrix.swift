public struct DenseColumnMajorMatrix<Scalar: Sendable>: Sendable {
    public let rows: Int
    public let columns: Int
    public internal(set) var values: [Scalar]

    public var leadingDimension: Int { rows }

    public init(rows: Int, columns: Int, columnMajorValues values: [Scalar]) throws {
        try Self.validateDimensions(rows: rows, columns: columns)
        try Self.validateValueCount(rows: rows, columns: columns, valueCount: values.count)

        self.rows = rows
        self.columns = columns
        self.values = values
    }

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

    public subscript(row row: Int, column column: Int) -> Scalar {
        get { values[column * leadingDimension + row] }
        set { values[column * leadingDimension + row] = newValue }
    }

    public func row(_ row: Int) -> [Scalar] {
        (0..<columns).map { column in
            self[row: row, column: column]
        }
    }

    public func column(_ column: Int) -> ArraySlice<Scalar> {
        let start = column * leadingDimension
        return values[start..<start + rows]
    }

    public func validatedTallMatrix() throws -> Self {
        guard rows >= columns else {
            throw MaxVolError.nonTallMatrix(rows: rows, columns: columns)
        }

        return self
    }
}

extension DenseColumnMajorMatrix: Equatable where Scalar: Equatable {}
extension DenseColumnMajorMatrix: Hashable where Scalar: Hashable {}
