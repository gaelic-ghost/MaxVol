/// Controls rectangular MaxVol row appends.
public struct RectMaxVolOptions: Equatable, Hashable, Sendable {
    /// The maximum allowed norm for unselected coefficient rows.
    ///
    /// Values must be finite and positive. The default follows the common
    /// rectangular MaxVol threshold.
    public let tolerance: Double

    /// The minimum number of rows to select.
    ///
    /// `nil` uses the input matrix column count.
    public let minRows: Int?

    /// The maximum number of rows to select.
    ///
    /// `nil` allows selecting every input row.
    public let maxRows: Int?

    /// The number of square MaxVol row-replacement iterations used for the initial basis.
    public let startMaxVolIterations: Int

    /// Creates RectMaxVol options.
    public init(
        tolerance: Double = 1.0,
        minRows: Int? = nil,
        maxRows: Int? = nil,
        startMaxVolIterations: Int = 10
    ) {
        self.tolerance = tolerance
        self.minRows = minRows
        self.maxRows = maxRows
        self.startMaxVolIterations = startMaxVolIterations
    }

    func resolved<Scalar>(for matrix: DenseColumnMajorMatrix<Scalar>) throws -> ResolvedRectMaxVolOptions {
        try resolved(rows: matrix.rows, columns: matrix.columns)
    }

    func resolved(rows: Int, columns: Int) throws -> ResolvedRectMaxVolOptions {
        guard tolerance.isFinite, tolerance > 0 else {
            throw MaxVolError.invalidTolerance(tolerance)
        }
        guard startMaxVolIterations >= 0 else {
            throw MaxVolError.invalidIterationLimit(startMaxVolIterations)
        }

        let requiredRows = columns
        let resolvedMinRows = minRows ?? requiredRows
        let resolvedMaxRows = maxRows ?? rows

        guard
            resolvedMinRows >= requiredRows,
            resolvedMaxRows >= requiredRows,
            resolvedMinRows <= resolvedMaxRows,
            resolvedMaxRows <= rows
        else {
            throw MaxVolError.invalidRowSelectionBounds(
                minRows: resolvedMinRows,
                maxRows: resolvedMaxRows,
                requiredRows: requiredRows,
                availableRows: rows
            )
        }

        return ResolvedRectMaxVolOptions(
            tolerance: tolerance,
            minRows: resolvedMinRows,
            maxRows: resolvedMaxRows,
            startMaxVolIterations: startMaxVolIterations
        )
    }
}

struct ResolvedRectMaxVolOptions: Equatable, Hashable {
    let tolerance: Double
    let minRows: Int
    let maxRows: Int
    let startMaxVolIterations: Int

    var toleranceSquared: Double { tolerance * tolerance }
}
