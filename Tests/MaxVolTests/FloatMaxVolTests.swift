@testable import MaxVol
import Testing

struct FloatMaxVolTests {
    // Reference fixture values in this suite were generated with
    // maxvolpy.maxvol.py_maxvol and py_rect_maxvol running on NumPy/SciPy
    // with np.float32 inputs.

    @Test func squareReferenceFixtureMatchesFloat32PivotsAndCoefficients() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.0))

        #expect(result.selectedRows == [2, 0])
        #expect(result.iterations == 1)
        #expect(result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                0.666_666_626_930_236_8, 0.666_666_686_534_881_6,
                1.0, 0.0,
            ]
        )
        #expect(maximumAbsoluteCoefficient(in: result.coefficients) == 1.0)
        try expectReconstruction(of: matrix, using: result)
    }

    @Test func zeroMaxIterationsReturnsFloat32InitialLUFixture() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 1.5,
            ]
        )

        let result = try maxVol(matrix, options: MaxVolOptions(maxIterations: 0))

        #expect(result.selectedRows == [1, 0])
        #expect(result.iterations == 0)
        #expect(!result.converged)
        try expectCoefficients(
            result.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                1.0, 0.0,
                1.5, -1.0,
            ]
        )
        #expect(maximumAbsoluteCoefficient(in: result.coefficients) == 1.5)
        try expectReconstruction(of: matrix, using: result)
    }

    @Test func iterationLimitReturnsFloat32PartialFixture() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 4,
            columns: 2,
            rowMajorValues: [
                0.25, 0.0,
                0.5, 1.0,
                0.5, 0.5,
                0.5, 1.5,
            ]
        )

        let limited = try maxVol(matrix, options: MaxVolOptions(maxIterations: 1))
        let converged = try maxVol(matrix, options: MaxVolOptions(maxIterations: 2))

        #expect(limited.selectedRows == [3, 0])
        #expect(limited.iterations == 1)
        #expect(!limited.converged)
        try expectCoefficients(
            limited.coefficients,
            rowMajorValues: [
                0.0, 1.0,
                0.666_666_626_930_236_8, 0.666_666_686_534_881_6,
                0.333_333_313_465_118_4, 1.333_333_373_069_763_2,
                1.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: limited)

        #expect(converged.selectedRows == [3, 2])
        #expect(converged.iterations == 2)
        #expect(converged.converged)
        try expectCoefficients(
            converged.coefficients,
            rowMajorValues: [
                -0.249_999_985_098_838_8, 0.75,
                0.499_999_970_197_677_6, 0.5,
                0.0, 1.0,
                1.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: converged)
    }

    @Test func rectangularReferenceFixtureAppendsRequiredMinimumRows() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
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
                0.509_615_361_690_521_2, 0.221_153_840_422_630_3, 0.038_461_539_894_342_42,
                0.0, 0.0, 1.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
    }

    @Test func rectangularReferenceFixtureRespectsMaximumRowsLimit() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
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
                0.666_666_626_930_236_8, 0.666_666_686_534_881_6,
                1.0, 0.0,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        #expect(maximumUnselectedRowNorm(in: result) > 0.9)
    }

    @Test func rectangularReferenceFixtureSelectsAllRowsWhenNeeded() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
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

    @Test func rectangularReferenceFixtureMatchesAppendCase() throws {
        let matrix = try DenseColumnMajorMatrix<Float>(
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
                0.011_215_145_699_679_852, 0.767_505_407_333_374, -0.090_208_716_690_540_31,
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.399_453_848_600_387_6, 0.553_930_222_988_128_7, 0.265_262_335_538_864_14,
            ]
        )
        try expectReconstruction(of: matrix, using: result)
        try expectSelectedRowsAreIdentity(result)
        #expect(maximumUnselectedRowNorm(in: result) <= 1.0)
    }

    @Test func randomizedOrthonormalTallMatrixSatisfiesFloatCriteria() throws {
        let matrix = try orthonormalColumns(rows: 14, columns: 5, seed: 0xF10A7).mapValues(Float.init)

        let square = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 100))
        #expect(square.selectedRows.count == matrix.columns)
        #expect(square.converged)
        #expect(maximumAbsoluteCoefficient(in: square.coefficients) <= 1.05 + 1e-6)
        try expectReconstruction(of: matrix, using: square, tolerance: 5e-5)

        let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 1.0))
        #expect(rectangular.selectedRows.count >= matrix.columns)
        #expect(rectangular.converged)
        #expect(maximumUnselectedRowNorm(in: rectangular) <= 1.0 + 1e-5)
        try expectReconstruction(of: matrix, using: rectangular, tolerance: 5e-5)
        try expectSelectedRowsAreIdentity(rectangular)
    }

    @Test func nearRankDeficientFloatInputThrowsDescriptiveError() throws {
        let epsilon = Float.ulpOfOne / 16
        let matrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                1.0, 1.0,
                2.0, 2.0 + epsilon,
                3.0, 3.0,
            ]
        )

        #expect(throws: MaxVolError.rankDeficient(pivot: 2)) {
            try maxVol(matrix)
        }
    }
}
