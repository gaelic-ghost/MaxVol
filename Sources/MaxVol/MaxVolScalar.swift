import Accelerate

typealias LAPACKInt = __LAPACK_int

protocol MaxVolScalar: BinaryFloatingPoint, Sendable {
    static var getrfRoutineName: String { get }
    static var getrsRoutineName: String { get }
    static var rankToleranceUnit: Double { get }

    var magnitudeAsDouble: Double { get }

    static func getrf(
        rowCount: inout LAPACKInt,
        columnCount: inout LAPACKInt,
        values: UnsafeMutablePointer<Self>?,
        leadingDimension: inout LAPACKInt,
        pivots: UnsafeMutablePointer<LAPACKInt>?,
        info: inout LAPACKInt
    )

    static func getrs(
        transpose: inout CChar,
        dimension: inout LAPACKInt,
        rightHandSides: inout LAPACKInt,
        factorization: UnsafeMutablePointer<Self>?,
        leadingDimension: inout LAPACKInt,
        pivots: UnsafeMutablePointer<LAPACKInt>?,
        rightHandSide: UnsafeMutablePointer<Self>?,
        rightHandSideLeadingDimension: inout LAPACKInt,
        info: inout LAPACKInt
    )

    static func rankOneUpdate(
        rowCount: LAPACKInt,
        columnCount: LAPACKInt,
        alpha: Self,
        x: UnsafePointer<Self>?,
        incrementX: LAPACKInt,
        y: UnsafePointer<Self>?,
        incrementY: LAPACKInt,
        values: UnsafeMutablePointer<Self>?,
        leadingDimension: LAPACKInt
    )
}

extension Double: MaxVolScalar {
    static var getrfRoutineName: String { "dgetrf" }
    static var getrsRoutineName: String { "dgetrs" }
    static var rankToleranceUnit: Double { Double.ulpOfOne }

    var magnitudeAsDouble: Double { abs(self) }

    static func getrf(
        rowCount: inout LAPACKInt,
        columnCount: inout LAPACKInt,
        values: UnsafeMutablePointer<Double>?,
        leadingDimension: inout LAPACKInt,
        pivots: UnsafeMutablePointer<LAPACKInt>?,
        info: inout LAPACKInt
    ) {
        dgetrf_(
            &rowCount,
            &columnCount,
            values,
            &leadingDimension,
            pivots,
            &info
        )
    }

    static func getrs(
        transpose: inout CChar,
        dimension: inout LAPACKInt,
        rightHandSides: inout LAPACKInt,
        factorization: UnsafeMutablePointer<Double>?,
        leadingDimension: inout LAPACKInt,
        pivots: UnsafeMutablePointer<LAPACKInt>?,
        rightHandSide: UnsafeMutablePointer<Double>?,
        rightHandSideLeadingDimension: inout LAPACKInt,
        info: inout LAPACKInt
    ) {
        dgetrs_(
            &transpose,
            &dimension,
            &rightHandSides,
            factorization,
            &leadingDimension,
            pivots,
            rightHandSide,
            &rightHandSideLeadingDimension,
            &info
        )
    }

    static func rankOneUpdate(
        rowCount: LAPACKInt,
        columnCount: LAPACKInt,
        alpha: Double,
        x: UnsafePointer<Double>?,
        incrementX: LAPACKInt,
        y: UnsafePointer<Double>?,
        incrementY: LAPACKInt,
        values: UnsafeMutablePointer<Double>?,
        leadingDimension: LAPACKInt
    ) {
        cblas_dger(
            CblasColMajor,
            rowCount,
            columnCount,
            alpha,
            x,
            incrementX,
            y,
            incrementY,
            values,
            leadingDimension
        )
    }
}

extension Float: MaxVolScalar {
    static var getrfRoutineName: String { "sgetrf" }
    static var getrsRoutineName: String { "sgetrs" }
    static var rankToleranceUnit: Double { Double(Float.ulpOfOne) }

    var magnitudeAsDouble: Double { Double(abs(self)) }

    static func getrf(
        rowCount: inout LAPACKInt,
        columnCount: inout LAPACKInt,
        values: UnsafeMutablePointer<Float>?,
        leadingDimension: inout LAPACKInt,
        pivots: UnsafeMutablePointer<LAPACKInt>?,
        info: inout LAPACKInt
    ) {
        sgetrf_(
            &rowCount,
            &columnCount,
            values,
            &leadingDimension,
            pivots,
            &info
        )
    }

    static func getrs(
        transpose: inout CChar,
        dimension: inout LAPACKInt,
        rightHandSides: inout LAPACKInt,
        factorization: UnsafeMutablePointer<Float>?,
        leadingDimension: inout LAPACKInt,
        pivots: UnsafeMutablePointer<LAPACKInt>?,
        rightHandSide: UnsafeMutablePointer<Float>?,
        rightHandSideLeadingDimension: inout LAPACKInt,
        info: inout LAPACKInt
    ) {
        sgetrs_(
            &transpose,
            &dimension,
            &rightHandSides,
            factorization,
            &leadingDimension,
            pivots,
            rightHandSide,
            &rightHandSideLeadingDimension,
            &info
        )
    }

    static func rankOneUpdate(
        rowCount: LAPACKInt,
        columnCount: LAPACKInt,
        alpha: Float,
        x: UnsafePointer<Float>?,
        incrementX: LAPACKInt,
        y: UnsafePointer<Float>?,
        incrementY: LAPACKInt,
        values: UnsafeMutablePointer<Float>?,
        leadingDimension: LAPACKInt
    ) {
        cblas_sger(
            CblasColMajor,
            rowCount,
            columnCount,
            alpha,
            x,
            incrementX,
            y,
            incrementY,
            values,
            leadingDimension
        )
    }
}

func lapackInt(_ value: Int) throws -> LAPACKInt {
    guard value <= Int(LAPACKInt.max) else {
        throw MaxVolError.invalidDimensions(rows: value, columns: value)
    }

    return LAPACKInt(value)
}

func validateLapackInfo(
    _ info: LAPACKInt,
    routine: String,
    rankDeficientInfoIsPivot: Bool
) throws {
    if info < 0 {
        throw MaxVolError.lapackFailure(routine: routine, info: Int(info))
    }
    if info > 0 {
        if rankDeficientInfoIsPivot {
            throw MaxVolError.rankDeficient(pivot: Int(info))
        }
        throw MaxVolError.lapackFailure(routine: routine, info: Int(info))
    }
}
