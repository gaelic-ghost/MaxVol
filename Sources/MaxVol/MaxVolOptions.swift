public struct MaxVolOptions: Equatable, Hashable, Sendable {
    public let tolerance: Double
    public let maxIterations: Int?

    public init(tolerance: Double = 1.05, maxIterations: Int? = nil) {
        self.tolerance = tolerance
        self.maxIterations = maxIterations
    }

    func validated() throws -> Self {
        guard tolerance.isFinite, tolerance > 1 else {
            throw MaxVolError.invalidTolerance(tolerance)
        }

        if let maxIterations {
            guard maxIterations >= 0 else {
                throw MaxVolError.invalidIterationLimit(maxIterations)
            }
        }

        return self
    }
}
