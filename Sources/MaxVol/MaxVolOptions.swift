/// Controls MaxVol row-replacement convergence.
public struct MaxVolOptions: Equatable, Hashable, Sendable {
    /// The maximum allowed absolute coefficient before another replacement is attempted.
    ///
    /// Values must be finite and at least `1.0`. The default follows the
    /// common practical MaxVol tolerance used to avoid unnecessary churn around
    /// exact equality.
    public let tolerance: Double

    /// The maximum number of row-replacement iterations.
    public let maxIterations: Int

    /// Creates MaxVol options.
    public init(tolerance: Double = 1.05, maxIterations: Int = 100) {
        self.tolerance = tolerance
        self.maxIterations = maxIterations
    }

    func validated() throws -> Self {
        guard tolerance.isFinite, tolerance >= 1 else {
            throw MaxVolError.invalidTolerance(tolerance)
        }
        guard maxIterations >= 0 else {
            throw MaxVolError.invalidIterationLimit(maxIterations)
        }

        return self
    }
}
