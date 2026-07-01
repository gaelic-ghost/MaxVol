public struct MaxVolResult<Scalar: Sendable>: Sendable {
    public let selectedRows: [Int]
    public let coefficients: DenseColumnMajorMatrix<Scalar>
    public let iterations: Int

    public init(
        selectedRows: [Int],
        coefficients: DenseColumnMajorMatrix<Scalar>,
        iterations: Int
    ) throws {
        try Self.validate(
            selectedRows: selectedRows,
            coefficients: coefficients,
            iterations: iterations
        )

        self.selectedRows = selectedRows
        self.coefficients = coefficients
        self.iterations = iterations
    }

    private static func validate(
        selectedRows: [Int],
        coefficients: DenseColumnMajorMatrix<Scalar>,
        iterations: Int
    ) throws {
        guard iterations >= 0 else {
            throw MaxVolError.invalidIterationCount(iterations)
        }
        guard selectedRows.count == coefficients.columns else {
            throw MaxVolError.coefficientColumnMismatch(
                selectedRows: selectedRows.count,
                coefficientColumns: coefficients.columns
            )
        }

        var seenRows = Set<Int>()
        for row in selectedRows {
            guard (0..<coefficients.rows).contains(row) else {
                throw MaxVolError.invalidSelectedRowIndex(row: row, availableRows: coefficients.rows)
            }
            guard seenRows.insert(row).inserted else {
                throw MaxVolError.duplicateSelectedRow(row: row)
            }
        }
    }
}

extension MaxVolResult: Equatable where Scalar: Equatable {}
extension MaxVolResult: Hashable where Scalar: Hashable {}
