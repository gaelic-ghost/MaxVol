/// Controls MaxVol row-replacement convergence.
public struct MaxVolOptions: Equatable, Hashable, Sendable {
    /// The maximum allowed absolute coefficient before another replacement is attempted.
    ///
    /// Values must be finite and greater than `1.0`. The default follows the
    /// common practical MaxVol tolerance used to avoid unnecessary churn around
    /// exact equality.
    public let tolerance: Double

    /// The maximum number of row-replacement iterations.
    ///
    /// `nil` uses the package default derived from the matrix dimensions.
    public let maxIterations: Int?

    /// Creates MaxVol options.
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
