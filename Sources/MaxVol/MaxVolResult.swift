/// The row selection and expansion coefficients produced by MaxVol.
public struct MaxVolResult<Scalar: Sendable>: Sendable {
    /// The selected row indices in the input matrix.
    public let selectedRows: [Int]

    /// Coefficients that reconstruct the input from the selected rows.
    ///
    /// For an input matrix `A`, the result is shaped so
    /// `A ~= coefficients * A[selectedRows, :]`.
    public let coefficients: DenseColumnMajorMatrix<Scalar>

    /// The number of row-replacement iterations performed after the initial basis.
    public let iterations: Int

    /// Whether the coefficient matrix satisfied the configured tolerance.
    public let converged: Bool

    /// Creates a validated result value.
    ///
    /// The selected row count must match the coefficient column count, selected
    /// rows must be unique and in bounds, and the iteration count must be
    /// nonnegative.
    public init(
        selectedRows: [Int],
        coefficients: DenseColumnMajorMatrix<Scalar>,
        iterations: Int,
        converged: Bool = true
    ) throws {
        try Self.validate(
            selectedRows: selectedRows,
            coefficients: coefficients,
            iterations: iterations
        )

        self.selectedRows = selectedRows
        self.coefficients = coefficients
        self.iterations = iterations
        self.converged = converged
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
