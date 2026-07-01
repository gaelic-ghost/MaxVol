public struct MaxVolResult<Scalar: Sendable>: Sendable {
    public let selectedRows: [Int]
    public let coefficients: DenseColumnMajorMatrix<Scalar>
    public let iterations: Int

    public init(
        selectedRows: [Int],
        coefficients: DenseColumnMajorMatrix<Scalar>,
        iterations: Int
    ) {
        self.selectedRows = selectedRows
        self.coefficients = coefficients
        self.iterations = iterations
    }
}

extension MaxVolResult: Equatable where Scalar: Equatable {}
extension MaxVolResult: Hashable where Scalar: Hashable {}
