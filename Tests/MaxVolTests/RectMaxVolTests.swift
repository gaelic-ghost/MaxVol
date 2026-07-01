@testable import MaxVol
import Testing

struct RectMaxVolTests {
    // Reference fixture values in this suite were generated with
    // maxvolpy.maxvol.py_rect_maxvol running on NumPy/SciPy.

    @Test func maxVolPyReferenceFixtureAppendsRequiredMinimumRows() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 4,
            columns: 2,
            rowMajorValues: [
                1.0, 0.0,
                0.0, 1.0,
                0.5, 0.25,
                -0.25, 0.75,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(minRows: 3))

        #expect(result.selectedRows == [0, 1, 3])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.509_615_384_615_384_6, 0.221_153_846_153_846_15, 0.038_461_538_461_538_464,
                0.0, 0.0, 1.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
    }

    @Test func maxVolPyReferenceFixtureRespectsMaximumRowsLimit() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 0.9, maxRows: 2))

        #expect(result.selectedRows == [2, 0])
        #expect(result.iterations == 0)
        #expect(!result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                2.0 / 3.0, 2.0 / 3.0,
                1.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        #expect(maximumUnselectedRowNorm(in: result) > 0.9)
    }

    @Test func maxVolPyReferenceFixtureSelectsAllRowsWhenNeeded() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 0.9, maxRows: 3))

        #expect(result.selectedRows == [2, 0, 1])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0, 0.0,
                0.0, 0.0, 1.0,
                1.0, 0.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
    }

    @Test func maxVolPyReferenceFixtureMatchesAppendCase() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 5,
            columns: 2,
            rowMajorValues: [
                1.0, 0.0,
                0.0, 1.0,
                1.2, 0.2,
                0.1, 1.3,
                0.8, 0.8,
            ]
        )

        let result = try rectMaxVol(matrix, options: RectMaxVolOptions(minRows: 3))

        #expect(result.selectedRows == [2, 3, 0])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 0.0, 1.0,
                0.011_215_135_556_855_861, 0.767_505_363_760_483_6, -0.090_208_699_044_275_4,
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.399_453_871_659_840_1, 0.553_930_173_590_793_9, 0.265_262_336_649_112_6,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
        #expect(maximumUnselectedRowNorm(in: result) <= 1.0)
    }

    @Test func invalidRectangularOptionsAreRejected() throws {
        let matrix = try DenseColumnMajorMatrix(
            rows: 4,
            columns: 2,
            rowMajorValues: [
                1.0, 0.0,
                0.0, 1.0,
                0.5, 0.25,
                -0.25, 0.75,
            ]
        )

        #expect(throws: MaxVolError.invalidTolerance(0.0)) {
            try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 0.0))
        }
        do {
            _ = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: .nan))
            Issue.record("RectMaxVol accepted NaN tolerance.")
        } catch let MaxVolError.invalidTolerance(tolerance) {
            #expect(tolerance.isNaN)
        } catch {
            Issue.record("RectMaxVol threw unexpected error for NaN tolerance: \(error).")
        }
        #expect(throws: MaxVolError.invalidIterationLimit(-1)) {
            try rectMaxVol(matrix, options: RectMaxVolOptions(startMaxVolIterations: -1))
        }
        #expect(
            throws: MaxVolError.invalidRowSelectionBounds(
                minRows: 1,
                maxRows: 4,
                requiredRows: 2,
                availableRows: 4
            )
        ) {
            try rectMaxVol(matrix, options: RectMaxVolOptions(minRows: 1))
        }
        #expect(
            throws: MaxVolError.invalidRowSelectionBounds(
                minRows: 3,
                maxRows: 2,
                requiredRows: 2,
                availableRows: 4
            )
        ) {
            try rectMaxVol(matrix, options: RectMaxVolOptions(minRows: 3, maxRows: 2))
        }
        #expect(
            throws: MaxVolError.invalidRowSelectionBounds(
                minRows: 2,
                maxRows: 5,
                requiredRows: 2,
                availableRows: 4
            )
        ) {
            try rectMaxVol(matrix, options: RectMaxVolOptions(maxRows: 5))
        }
    }

    @Test func randomizedOrthonormalTallMatrixSatisfiesSquareAndRectangularCriteria() throws {
        let matrix = try orthonormalColumns(rows: 12, columns: 4, seed: 0xC0FFEE)

        let square = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 100))
        #expect(square.selectedRows.count == matrix.columns)
        #expect(square.converged)
        #expect(maximumAbsoluteCoefficient(in: square.coefficients) <= 1.05)
        try expectReconstruction(of: matrix, using: square, tolerance: 1e-9)

        let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 1.0))
        #expect(rectangular.selectedRows.count >= matrix.columns)
        #expect(rectangular.converged)
        #expect(maximumUnselectedRowNorm(in: rectangular) <= 1.0 + 1e-12)
        try expectReconstruction(of: matrix, using: rectangular, tolerance: 1e-9)
        try expectSelectedRowsAreIdentity(rectangular)
    }
}
