@testable import MaxVol
import Testing

struct NumericalBehaviorTests {
    @Test func randomizedOrthonormalMatricesSatisfyDoubleCriteriaAcrossSizes() throws {
        for (rows, columns, seed) in [
            (8, 3, UInt64(0xD011_0001)),
            (13, 4, UInt64(0xD011_0002)),
            (21, 6, UInt64(0xD011_0003)),
        ] {
            let matrix = try orthonormalColumns(rows: rows, columns: columns, seed: seed)

            let square = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 200))
            #expect(square.selectedRows.count == matrix.columns)
            #expect(square.converged)
            #expect(maximumAbsoluteCoefficient(in: square.coefficients) <= 1.05)
            try expectReconstruction(of: matrix, using: square, tolerance: 1e-9)

            let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 1.0))
            #expect(rectangular.selectedRows.count >= matrix.columns)
            #expect(rectangular.converged)
            #expect(maximumUnselectedRowNorm(in: rectangular) <= 1.0 + 1e-12)
            try expectReconstruction(of: matrix, using: rectangular, tolerance: 1e-9)
        }
    }

    @Test func randomizedOrthonormalMatricesSatisfyFloatCriteriaAcrossSizes() throws {
        for (rows, columns, seed) in [
            (8, 3, UInt64(0xF10A_0001)),
            (13, 4, UInt64(0xF10A_0002)),
            (21, 6, UInt64(0xF10A_0003)),
        ] {
            let matrix = try orthonormalColumns(rows: rows, columns: columns, seed: seed).mapValues(Float.init)

            let square = try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 200))
            #expect(square.selectedRows.count == matrix.columns)
            #expect(square.converged)
            #expect(maximumAbsoluteCoefficient(in: square.coefficients) <= 1.05 + 1e-6)
            try expectReconstruction(of: matrix, using: square, tolerance: 5e-5)

            let rectangular = try rectMaxVol(matrix, options: RectMaxVolOptions(tolerance: 1.0))
            #expect(rectangular.selectedRows.count >= matrix.columns)
            #expect(rectangular.converged)
            #expect(maximumUnselectedRowNorm(in: rectangular) <= 1.0 + 1e-5)
            try expectReconstruction(of: matrix, using: rectangular, tolerance: 5e-5)
        }
    }

    @Test func nearRankDeficientDoubleAndFloatInputsThrowDescriptiveErrors() throws {
        let doubleMatrix = try DenseColumnMajorMatrix<Double>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                1.0, 1.0,
                2.0, 2.0 + Double.ulpOfOne / 16,
                3.0, 3.0,
            ]
        )
        let floatMatrix = try DenseColumnMajorMatrix<Float>(
            rows: 3,
            columns: 2,
            rowMajorValues: [
                1.0, 1.0,
                2.0, 2.0 + Float.ulpOfOne / 16,
                3.0, 3.0,
            ]
        )

        #expect(throws: MaxVolError.rankDeficient(pivot: 2)) {
            try maxVol(doubleMatrix)
        }
        #expect(throws: MaxVolError.rankDeficient(pivot: 2)) {
            try maxVol(floatMatrix)
        }
    }
}
