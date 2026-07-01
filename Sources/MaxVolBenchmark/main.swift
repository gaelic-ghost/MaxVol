import Foundation
import MaxVol

struct FixtureFile: Decodable {
    let version: Int
    let source: String
    let fixtures: [BenchmarkFixture]
}

struct BenchmarkFixture: Decodable {
    let id: String
    let description: String
    let rows: Int
    let columns: Int
    let rowMajorValues: [Double]
}

struct BenchmarkConfiguration {
    var fixtureFilter: String?
    var algorithmFilter = BenchmarkAlgorithm.all
    var scalarFilter = BenchmarkScalar.all
    var iterations = 10
    var rectangularMinRows: Int?
}

enum BenchmarkAlgorithm: String, CaseIterable {
    case all
    case square
    case rectangular

    var selectedAlgorithms: [BenchmarkAlgorithm] {
        switch self {
            case .all:
                [.square, .rectangular]
            case .square, .rectangular:
                [self]
        }
    }
}

enum BenchmarkScalar: String, CaseIterable {
    case all
    case double
    case float

    var selectedScalars: [BenchmarkScalar] {
        switch self {
            case .all:
                [.double, .float]
            case .double, .float:
                [self]
        }
    }
}

struct BenchmarkRecord: Encodable {
    let tool: String
    let fixture: String
    let algorithm: String
    let scalar: String
    let rows: Int
    let columns: Int
    let repetitions: Int
    let elapsedNanoseconds: UInt64
    let averageNanoseconds: Double
    let selectedRowCount: Int
    let algorithmIterations: Int
    let converged: Bool
    let maxCoefficientMagnitude: Double
    let maxUnselectedRowNorm: Double?
    let reconstructionResidual: Double
}

enum BenchmarkError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case missingArgumentValue(String)
    case missingFixtureResource
    case fixtureNotFound(String)

    var description: String {
        switch self {
            case let .invalidArgument(argument):
                "Unrecognized MaxVolBenchmark argument '\(argument)'."
            case let .missingArgumentValue(argument):
                "MaxVolBenchmark argument '\(argument)' requires a value."
            case .missingFixtureResource:
                "MaxVolBenchmark could not find its bundled fixtures.json resource. Rebuild the MaxVolBenchmark product and verify the package resource is declared in Package.swift."
            case let .fixtureNotFound(identifier):
                "No benchmark fixture matched '\(identifier)'."
        }
    }
}

let configuration = try parseArguments(Array(CommandLine.arguments.dropFirst()))
let fixtureFile = try loadFixtureFile()
let fixtures = try selectedFixtures(from: fixtureFile, configuration: configuration)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

for fixture in fixtures {
    for algorithm in configuration.algorithmFilter.selectedAlgorithms {
        for scalar in configuration.scalarFilter.selectedScalars {
            let record = try runBenchmark(
                fixture: fixture,
                algorithm: algorithm,
                scalar: scalar,
                configuration: configuration
            )
            let data = try encoder.encode(record)
            print(String(decoding: data, as: UTF8.self))
        }
    }
}

func parseArguments(_ arguments: [String]) throws -> BenchmarkConfiguration {
    var configuration = BenchmarkConfiguration()
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
            case "--fixture":
                configuration.fixtureFilter = try value(after: argument, at: &index, in: arguments)
            case "--algorithm":
                let rawValue = try value(after: argument, at: &index, in: arguments)
                guard let algorithm = BenchmarkAlgorithm(rawValue: rawValue) else {
                    throw BenchmarkError.invalidArgument("\(argument) \(rawValue)")
                }

                configuration.algorithmFilter = algorithm
            case "--scalar":
                let rawValue = try value(after: argument, at: &index, in: arguments)
                guard let scalar = BenchmarkScalar(rawValue: rawValue) else {
                    throw BenchmarkError.invalidArgument("\(argument) \(rawValue)")
                }

                configuration.scalarFilter = scalar
            case "--iterations":
                let rawValue = try value(after: argument, at: &index, in: arguments)
                guard let iterations = Int(rawValue), iterations > 0 else {
                    throw BenchmarkError.invalidArgument("\(argument) \(rawValue)")
                }

                configuration.iterations = iterations
            case "--rectangular-min-rows":
                let rawValue = try value(after: argument, at: &index, in: arguments)
                guard let minRows = Int(rawValue), minRows > 0 else {
                    throw BenchmarkError.invalidArgument("\(argument) \(rawValue)")
                }

                configuration.rectangularMinRows = minRows
            case "--help", "-h":
                printUsage()
                Foundation.exit(0)
            default:
                throw BenchmarkError.invalidArgument(argument)
        }
        index += 1
    }

    return configuration
}

func value(after argument: String, at index: inout Int, in arguments: [String]) throws -> String {
    let valueIndex = index + 1
    guard valueIndex < arguments.count else {
        throw BenchmarkError.missingArgumentValue(argument)
    }

    index = valueIndex
    return arguments[valueIndex]
}

func printUsage() {
    print(
        """
        Usage: MaxVolBenchmark [--fixture <id>] [--algorithm all|square|rectangular] [--scalar all|double|float] [--iterations <count>] [--rectangular-min-rows <count>]

        Prints one JSON object per benchmark result. Build with:
          swift build -c release --product MaxVolBenchmark
        """
    )
}

func loadFixtureFile() throws -> FixtureFile {
    guard let url = Bundle.module.url(forResource: "fixtures", withExtension: "json") else {
        throw BenchmarkError.missingFixtureResource
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(FixtureFile.self, from: data)
}

func selectedFixtures(
    from fixtureFile: FixtureFile,
    configuration: BenchmarkConfiguration
) throws -> [BenchmarkFixture] {
    guard let fixtureFilter = configuration.fixtureFilter else {
        return fixtureFile.fixtures
    }

    let fixtures = fixtureFile.fixtures.filter { $0.id == fixtureFilter }
    guard !fixtures.isEmpty else {
        throw BenchmarkError.fixtureNotFound(fixtureFilter)
    }

    return fixtures
}

func runBenchmark(
    fixture: BenchmarkFixture,
    algorithm: BenchmarkAlgorithm,
    scalar: BenchmarkScalar,
    configuration: BenchmarkConfiguration
) throws -> BenchmarkRecord {
    switch scalar {
        case .double:
            return try runDoubleBenchmark(
                fixture: fixture,
                algorithm: algorithm,
                configuration: configuration
            )
        case .float:
            return try runFloatBenchmark(
                fixture: fixture,
                algorithm: algorithm,
                configuration: configuration
            )
        case .all:
            preconditionFailure("Expanded scalar filters should not include .all.")
    }
}

func runDoubleBenchmark(
    fixture: BenchmarkFixture,
    algorithm: BenchmarkAlgorithm,
    configuration: BenchmarkConfiguration
) throws -> BenchmarkRecord {
    let matrix = try DenseColumnMajorMatrix<Double>(
        rows: fixture.rows,
        columns: fixture.columns,
        rowMajorValues: fixture.rowMajorValues
    )
    _ = try runDoubleAlgorithm(matrix, algorithm: algorithm, configuration: configuration)

    let start = DispatchTime.now().uptimeNanoseconds
    var latest = try runDoubleAlgorithm(matrix, algorithm: algorithm, configuration: configuration)
    for _ in 1..<configuration.iterations {
        latest = try runDoubleAlgorithm(matrix, algorithm: algorithm, configuration: configuration)
    }
    let elapsed = DispatchTime.now().uptimeNanoseconds - start

    return try BenchmarkRecord(
        tool: "MaxVolBenchmark",
        fixture: fixture.id,
        algorithm: algorithm.rawValue,
        scalar: BenchmarkScalar.double.rawValue,
        rows: fixture.rows,
        columns: fixture.columns,
        repetitions: configuration.iterations,
        elapsedNanoseconds: elapsed,
        averageNanoseconds: Double(elapsed) / Double(configuration.iterations),
        selectedRowCount: latest.selectedRows.count,
        algorithmIterations: latest.iterations,
        converged: latest.converged,
        maxCoefficientMagnitude: maximumAbsoluteCoefficient(in: latest.coefficients),
        maxUnselectedRowNorm: algorithm == .rectangular ? maximumUnselectedRowNorm(in: latest) : nil,
        reconstructionResidual: reconstructionResidual(matrix: matrix, result: latest)
    )
}

func runFloatBenchmark(
    fixture: BenchmarkFixture,
    algorithm: BenchmarkAlgorithm,
    configuration: BenchmarkConfiguration
) throws -> BenchmarkRecord {
    let matrix = try DenseColumnMajorMatrix<Float>(
        rows: fixture.rows,
        columns: fixture.columns,
        rowMajorValues: fixture.rowMajorValues.map(Float.init)
    )
    _ = try runFloatAlgorithm(matrix, algorithm: algorithm, configuration: configuration)

    let start = DispatchTime.now().uptimeNanoseconds
    var latest = try runFloatAlgorithm(matrix, algorithm: algorithm, configuration: configuration)
    for _ in 1..<configuration.iterations {
        latest = try runFloatAlgorithm(matrix, algorithm: algorithm, configuration: configuration)
    }
    let elapsed = DispatchTime.now().uptimeNanoseconds - start

    return try BenchmarkRecord(
        tool: "MaxVolBenchmark",
        fixture: fixture.id,
        algorithm: algorithm.rawValue,
        scalar: BenchmarkScalar.float.rawValue,
        rows: fixture.rows,
        columns: fixture.columns,
        repetitions: configuration.iterations,
        elapsedNanoseconds: elapsed,
        averageNanoseconds: Double(elapsed) / Double(configuration.iterations),
        selectedRowCount: latest.selectedRows.count,
        algorithmIterations: latest.iterations,
        converged: latest.converged,
        maxCoefficientMagnitude: maximumAbsoluteCoefficient(in: latest.coefficients),
        maxUnselectedRowNorm: algorithm == .rectangular ? maximumUnselectedRowNorm(in: latest) : nil,
        reconstructionResidual: Double(reconstructionResidual(matrix: matrix, result: latest))
    )
}

func runDoubleAlgorithm(
    _ matrix: DenseColumnMajorMatrix<Double>,
    algorithm: BenchmarkAlgorithm,
    configuration: BenchmarkConfiguration
) throws -> MaxVolResult<Double> {
    switch algorithm {
        case .square:
            try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 200))
        case .rectangular:
            try rectMaxVol(
                matrix,
                options: RectMaxVolOptions(
                    tolerance: 1.0,
                    minRows: configuration.rectangularMinRows,
                    startMaxVolIterations: 10
                )
            )
        case .all:
            preconditionFailure("Expanded algorithm filters should not include .all.")
    }
}

func runFloatAlgorithm(
    _ matrix: DenseColumnMajorMatrix<Float>,
    algorithm: BenchmarkAlgorithm,
    configuration: BenchmarkConfiguration
) throws -> MaxVolResult<Float> {
    switch algorithm {
        case .square:
            try maxVol(matrix, options: MaxVolOptions(tolerance: 1.05, maxIterations: 200))
        case .rectangular:
            try rectMaxVol(
                matrix,
                options: RectMaxVolOptions(
                    tolerance: 1.0,
                    minRows: configuration.rectangularMinRows,
                    startMaxVolIterations: 10
                )
            )
        case .all:
            preconditionFailure("Expanded algorithm filters should not include .all.")
    }
}

func maximumAbsoluteCoefficient(
    in coefficients: DenseColumnMajorMatrix<Double>
) -> Double {
    coefficients.values.map(abs).max() ?? 0
}

func maximumAbsoluteCoefficient(
    in coefficients: DenseColumnMajorMatrix<Float>
) -> Double {
    coefficients.values.map { Double(abs($0)) }.max() ?? 0
}

func maximumUnselectedRowNorm(in result: MaxVolResult<Double>) -> Double {
    let selected = Set(result.selectedRows)
    return (0..<result.coefficients.rows)
        .filter { !selected.contains($0) }
        .map { row in
            let normSquared = (0..<result.coefficients.columns).reduce(0.0) { total, column in
                let coefficient = result.coefficients.values[
                    column * result.coefficients.leadingDimension + row
                ]
                return total + coefficient * coefficient
            }
            return normSquared.squareRoot()
        }
        .max() ?? 0
}

func maximumUnselectedRowNorm(in result: MaxVolResult<Float>) -> Double {
    let selected = Set(result.selectedRows)
    return (0..<result.coefficients.rows)
        .filter { !selected.contains($0) }
        .map { row in
            let normSquared = (0..<result.coefficients.columns).reduce(0.0) { total, column in
                let coefficient = Double(result.coefficients.values[
                    column * result.coefficients.leadingDimension + row
                ])
                return total + coefficient * coefficient
            }
            return normSquared.squareRoot()
        }
        .max() ?? 0
}

func reconstructionResidual(
    matrix: DenseColumnMajorMatrix<Double>,
    result: MaxVolResult<Double>
) throws -> Double {
    var residual = 0.0
    for row in 0..<matrix.rows {
        for column in 0..<matrix.columns {
            var reconstructed = 0.0
            for selectedColumn in 0..<result.selectedRows.count {
                reconstructed += try result.coefficients.value(row: row, column: selectedColumn)
                    * matrix.value(row: result.selectedRows[selectedColumn], column: column)
            }
            residual = try max(residual, abs(matrix.value(row: row, column: column) - reconstructed))
        }
    }
    return residual
}

func reconstructionResidual(
    matrix: DenseColumnMajorMatrix<Float>,
    result: MaxVolResult<Float>
) throws -> Float {
    var residual: Float = 0
    for row in 0..<matrix.rows {
        for column in 0..<matrix.columns {
            var reconstructed: Float = 0
            for selectedColumn in 0..<result.selectedRows.count {
                reconstructed += try result.coefficients.value(row: row, column: selectedColumn)
                    * matrix.value(row: result.selectedRows[selectedColumn], column: column)
            }
            residual = try max(residual, abs(matrix.value(row: row, column: column) - reconstructed))
        }
    }
    return residual
}
