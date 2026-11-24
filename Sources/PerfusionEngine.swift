import Foundation

enum PerfusionSignalMode: String, CaseIterable, Sendable {
    case relativeT1 = "T1-DCE: relative enhancement"
    case absoluteT1 = "T1-DCE: signal enhancement"
    case relativeT2Star = "T2*-DSC: -ln(S/S0)"
}

enum PerfusionModel: String, CaseIterable, Sendable {
    case standardTofts = "Standard Tofts"
    case extendedTofts = "Extended Tofts"
    case deconvolution = "Regularized deconvolution"
}

struct PerfusionConfiguration: Sendable, Equatable {
    var model: PerfusionModel
    var signalMode: PerfusionSignalMode
    var baselineFrames: Int
    var hematocrit: Double
    var regularization: Double
    var lowSignalFraction: Double
}

struct PerfusionFit: Sendable, Equatable {
    var primary: Double
    var secondary: Double
    var tertiary: Double
    var rSquared: Double
    var isValid: Bool

    static let invalid = PerfusionFit(
        primary: 0,
        secondary: 0,
        tertiary: 0,
        rSquared: 0,
        isValid: false
    )
}

struct PerfusionMapResult: Sendable, Equatable {
    var primary: [Float]
    var secondary: [Float]
    var tertiary: [Float]
    var quality: [Float]
    var invalidVoxelCount: Int
}

enum PerfusionEngineError: LocalizedError, Equatable {
    case insufficientTimepoints
    case invalidBaseline
    case invalidTimes
    case countMismatch
    case invalidConfiguration(String)
    case singularSystem

    var errorDescription: String? {
        switch self {
        case .insufficientTimepoints:
            return "At least four dynamic phases are required."
        case .invalidBaseline:
            return "The baseline must contain at least one phase and leave at least two post-baseline phases."
        case .invalidTimes:
            return "Acquisition times must be finite and strictly increasing."
        case .countMismatch:
            return "Signal, AIF and time arrays have incompatible lengths."
        case .invalidConfiguration(let message):
            return message
        case .singularSystem:
            return "The perfusion model could not be prepared because its linear system is singular."
        }
    }
}

enum PerfusionEngine {
    struct PreparedModel: Sendable {
        fileprivate enum Storage: Sendable {
            case tofts(aif: [Double], timesMinutes: [Double], candidates: [ToftsCandidate], extended: Bool)
            case deconvolution(kernel: [[Double]], convolution: [[Double]], deltaSeconds: Double)
        }

        fileprivate struct ToftsCandidate: Sendable {
            let kep: Double
            let basis: [Double]
            let hh: Double
            let hc: Double
            let determinant: Double
        }

        fileprivate let storage: Storage
        let sampleCount: Int
    }

    static func validate(times: [Double], configuration: PerfusionConfiguration) throws {
        guard times.count >= 4 else { throw PerfusionEngineError.insufficientTimepoints }
        guard configuration.baselineFrames > 0,
              configuration.baselineFrames <= times.count - 2 else {
            throw PerfusionEngineError.invalidBaseline
        }
        guard times.allSatisfy(\.isFinite),
              zip(times.dropFirst(), times).allSatisfy({ $0.0 > $0.1 }) else {
            throw PerfusionEngineError.invalidTimes
        }
        guard configuration.hematocrit.isFinite,
              configuration.hematocrit >= 0,
              configuration.hematocrit < 0.9 else {
            throw PerfusionEngineError.invalidConfiguration("Hematocrit must be between 0 and 0.9.")
        }
        guard configuration.regularization.isFinite,
              configuration.regularization > 0,
              configuration.regularization <= 1 else {
            throw PerfusionEngineError.invalidConfiguration("Regularization must be greater than 0 and at most 1.")
        }
        guard configuration.lowSignalFraction.isFinite,
              (0...1).contains(configuration.lowSignalFraction) else {
            throw PerfusionEngineError.invalidConfiguration("The low-signal threshold must be between 0 and 1.")
        }
    }

    static func concentration(
        signal: [Double],
        baselineFrames: Int,
        mode: PerfusionSignalMode
    ) throws -> [Double] {
        guard baselineFrames > 0, baselineFrames < signal.count else {
            throw PerfusionEngineError.invalidBaseline
        }
        guard signal.allSatisfy(\.isFinite) else { throw PerfusionEngineError.countMismatch }
        let baseline = signal.prefix(baselineFrames).reduce(0, +) / Double(baselineFrames)
        guard abs(baseline) > 1e-12 else { throw PerfusionEngineError.invalidBaseline }

        switch mode {
        case .relativeT1:
            return signal.map { ($0 - baseline) / baseline }
        case .absoluteT1:
            return signal.map { $0 - baseline }
        case .relativeT2Star:
            return signal.map { sample in
                guard sample > 0, baseline > 0 else { return .nan }
                return -log(sample / baseline)
            }
        }
    }

    static func prepare(
        aifSignal: [Double],
        timesSeconds: [Double],
        configuration: PerfusionConfiguration
    ) throws -> PreparedModel {
        try validate(times: timesSeconds, configuration: configuration)
        guard aifSignal.count == timesSeconds.count else { throw PerfusionEngineError.countMismatch }
        var aif = try concentration(
            signal: aifSignal,
            baselineFrames: configuration.baselineFrames,
            mode: configuration.signalMode
        )
        let plasmaFraction = 1 - configuration.hematocrit
        aif = aif.map { value in
            guard value.isFinite else { return 0 }
            return max(0, value / plasmaFraction)
        }

        switch configuration.model {
        case .standardTofts, .extendedTofts:
            let time0 = timesSeconds[0]
            let timesMinutes = timesSeconds.map { ($0 - time0) / 60 }
            let cc = dot(aif, aif)
            let kepCandidates = logarithmicGrid(minimum: 0.03, maximum: 6, count: 48)
            let candidates = kepCandidates.map { kep -> PreparedModel.ToftsCandidate in
                let basis = exponentialConvolution(input: aif, times: timesMinutes, rate: kep)
                let hh = dot(basis, basis)
                let hc = dot(basis, aif)
                return PreparedModel.ToftsCandidate(
                    kep: kep,
                    basis: basis,
                    hh: hh,
                    hc: hc,
                    determinant: hh * cc - hc * hc
                )
            }
            return PreparedModel(
                storage: .tofts(
                    aif: aif,
                    timesMinutes: timesMinutes,
                    candidates: candidates,
                    extended: configuration.model == .extendedTofts
                ),
                sampleCount: aif.count
            )
        case .deconvolution:
            let delta = median(zip(timesSeconds.dropFirst(), timesSeconds).map { $0.0 - $0.1 }) ?? 1
            let convolution = lowerTriangularConvolutionMatrix(aif: aif, delta: delta)
            let transpose = transposed(convolution)
            var normal = multiply(transpose, convolution)
            let diagonalMaximum = normal.indices.map { normal[$0][$0] }.max() ?? 1
            let lambda = max(1e-12, configuration.regularization * diagonalMaximum)
            for index in normal.indices { normal[index][index] += lambda }
            let inverse = try invert(normal)
            let kernel = multiply(inverse, transpose)
            return PreparedModel(
                storage: .deconvolution(kernel: kernel, convolution: convolution, deltaSeconds: delta),
                sampleCount: aif.count
            )
        }
    }

    static func fit(
        signal: [Double],
        prepared: PreparedModel,
        configuration: PerfusionConfiguration
    ) -> PerfusionFit {
        guard signal.count == prepared.sampleCount,
              let tissue = try? concentration(
                signal: signal,
                baselineFrames: configuration.baselineFrames,
                mode: configuration.signalMode
              ),
              tissue.allSatisfy(\.isFinite) else { return .invalid }

        switch prepared.storage {
        case .tofts(let aif, _, let candidates, let extended):
            return fitTofts(tissue: tissue, aif: aif, candidates: candidates, extended: extended)
        case .deconvolution(let kernel, let convolution, let deltaSeconds):
            let residue = matrixVector(kernel, tissue).map { max(0, $0) }
            guard let flowPerSecond = residue.max(), flowPerSecond.isFinite, flowPerSecond > 0 else {
                return .invalid
            }
            let volumeFraction = residue.reduce(0, +) * deltaSeconds
            let mttSeconds = volumeFraction / flowPerSecond
            guard volumeFraction.isFinite, mttSeconds.isFinite else { return .invalid }
            let predicted = matrixVector(convolution, residue)
            let quality = coefficientOfDetermination(observed: tissue, predicted: predicted)
            return PerfusionFit(
                primary: flowPerSecond * 6_000,
                secondary: max(0, volumeFraction * 100),
                tertiary: max(0, mttSeconds),
                rSquared: quality,
                isValid: true
            )
        }
    }

    static func fitMap(
        signalPlanes: [[Float]],
        aifSignal: [Double],
        timesSeconds: [Double],
        configuration: PerfusionConfiguration
    ) throws -> PerfusionMapResult {
        let prepared = try prepare(
            aifSignal: aifSignal,
            timesSeconds: timesSeconds,
            configuration: configuration
        )
        return try fitMap(signalPlanes: signalPlanes, prepared: prepared, configuration: configuration)
    }

    static func fitMap(
        signalPlanes: [[Float]],
        prepared: PreparedModel,
        configuration: PerfusionConfiguration,
        progress: (Int, Int) throws -> Void = { _, _ in }
    ) throws -> PerfusionMapResult {
        guard signalPlanes.count == prepared.sampleCount,
              let pixelCount = signalPlanes.first?.count,
              pixelCount > 0,
              signalPlanes.allSatisfy({ $0.count == pixelCount }) else {
            throw PerfusionEngineError.countMismatch
        }
        var primary = [Float](repeating: 0, count: pixelCount)
        var secondary = [Float](repeating: 0, count: pixelCount)
        var tertiary = [Float](repeating: 0, count: pixelCount)
        var quality = [Float](repeating: 0, count: pixelCount)
        var invalid = 0
        var signal = [Double](repeating: 0, count: signalPlanes.count)

        let baselineMaximum = (0..<pixelCount).reduce(0.0) { current, pixel in
            let mean = (0..<configuration.baselineFrames).reduce(0.0) {
                $0 + Double(signalPlanes[$1][pixel])
            } / Double(configuration.baselineFrames)
            return mean.isFinite ? max(current, mean) : current
        }
        let threshold = baselineMaximum * configuration.lowSignalFraction

        let batchSize = max(1, min(512, pixelCount / 100))
        for pixel in 0..<pixelCount {
            if pixel.isMultiple(of: batchSize) { try progress(pixel, pixelCount) }
            var baseline = 0.0
            for phase in signalPlanes.indices {
                signal[phase] = Double(signalPlanes[phase][pixel])
                if phase < configuration.baselineFrames { baseline += signal[phase] }
            }
            baseline /= Double(configuration.baselineFrames)
            guard baseline.isFinite, baseline > threshold else {
                invalid += 1
                continue
            }
            let result = fit(signal: signal, prepared: prepared, configuration: configuration)
            guard result.isValid else {
                invalid += 1
                continue
            }
            primary[pixel] = Float(result.primary)
            secondary[pixel] = Float(result.secondary)
            tertiary[pixel] = Float(result.tertiary)
            quality[pixel] = Float(max(0, min(1, result.rSquared)))
        }
        try progress(pixelCount, pixelCount)
        return PerfusionMapResult(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            quality: quality,
            invalidVoxelCount: invalid
        )
    }

    static func simulateTofts(
        aif: [Double],
        timesMinutes: [Double],
        kTrans: Double,
        ve: Double,
        vp: Double = 0
    ) -> [Double] {
        let kep = kTrans / ve
        let basis = exponentialConvolution(input: aif, times: timesMinutes, rate: kep)
        return zip(basis, aif).map { kTrans * $0.0 + vp * $0.1 }
    }

    private static func fitTofts(
        tissue: [Double],
        aif: [Double],
        candidates: [PreparedModel.ToftsCandidate],
        extended: Bool
    ) -> PerfusionFit {
        let cc = dot(aif, aif)
        let cy = dot(aif, tissue)
        var best: (kTrans: Double, ve: Double, vp: Double)?
        var bestSSE = Double.infinity

        for candidate in candidates where candidate.hh > 1e-14 {
            let hy = dot(candidate.basis, tissue)
            let kTrans: Double
            let vp: Double
            if extended {
                guard abs(candidate.determinant) > 1e-14 else { continue }
                kTrans = (hy * cc - cy * candidate.hc) / candidate.determinant
                vp = (cy * candidate.hh - hy * candidate.hc) / candidate.determinant
            } else {
                kTrans = hy / candidate.hh
                vp = 0
            }
            guard kTrans.isFinite, vp.isFinite, kTrans >= 0, kTrans <= 5,
                  vp >= 0, vp <= 1 else { continue }
            let ve = kTrans / candidate.kep
            guard ve.isFinite, ve > 0, ve <= 1.2 else { continue }
            var sse = 0.0
            for index in tissue.indices {
                let predicted = kTrans * candidate.basis[index] + vp * aif[index]
                let residual = tissue[index] - predicted
                sse += residual * residual
            }
            if sse < bestSSE {
                bestSSE = sse
                best = (kTrans, ve, vp)
            }
        }
        guard let best else { return .invalid }
        let mean = tissue.reduce(0, +) / Double(tissue.count)
        let total = tissue.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        return PerfusionFit(
            primary: best.kTrans,
            secondary: best.ve * 100,
            tertiary: best.vp * 100,
            rSquared: total > 1e-14 ? max(-1, min(1, 1 - bestSSE / total)) : 0,
            isValid: true
        )
    }

    private static func exponentialConvolution(input: [Double], times: [Double], rate: Double) -> [Double] {
        guard input.count == times.count, !input.isEmpty else { return [] }
        var result = [Double](repeating: 0, count: input.count)
        for index in 1..<input.count {
            let dt = times[index] - times[index - 1]
            let decay = exp(-rate * dt)
            result[index] = result[index - 1] * decay
                + 0.5 * dt * (input[index - 1] * decay + input[index])
        }
        return result
    }

    private static func lowerTriangularConvolutionMatrix(aif: [Double], delta: Double) -> [[Double]] {
        var matrix = [[Double]](repeating: [Double](repeating: 0, count: aif.count), count: aif.count)
        for row in aif.indices {
            for column in 0...row {
                matrix[row][column] = aif[row - column] * delta
            }
        }
        return matrix
    }

    private static func coefficientOfDetermination(observed: [Double], predicted: [Double]) -> Double {
        guard observed.count == predicted.count, !observed.isEmpty else { return 0 }
        let mean = observed.reduce(0, +) / Double(observed.count)
        let total = observed.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        guard total > 1e-14 else { return 0 }
        let residual = zip(observed, predicted).reduce(0.0) {
            $0 + ($1.0 - $1.1) * ($1.0 - $1.1)
        }
        return max(-1, min(1, 1 - residual / total))
    }

    private static func logarithmicGrid(minimum: Double, maximum: Double, count: Int) -> [Double] {
        let lower = log(minimum)
        let step = (log(maximum) - lower) / Double(count - 1)
        return (0..<count).map { exp(lower + Double($0) * step) }
    }

    private static func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
        zip(lhs, rhs).reduce(0.0) { $0 + $1.0 * $1.1 }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    private static func transposed(_ matrix: [[Double]]) -> [[Double]] {
        guard let width = matrix.first?.count else { return [] }
        return (0..<width).map { column in matrix.map { $0[column] } }
    }

    private static func multiply(_ lhs: [[Double]], _ rhs: [[Double]]) -> [[Double]] {
        guard let columns = rhs.first?.count else { return [] }
        let rhsT = transposed(rhs)
        return lhs.map { row in
            (0..<columns).map { column in dot(row, rhsT[column]) }
        }
    }

    private static func matrixVector(_ matrix: [[Double]], _ vector: [Double]) -> [Double] {
        matrix.map { dot($0, vector) }
    }

    private static func invert(_ matrix: [[Double]]) throws -> [[Double]] {
        let count = matrix.count
        guard count > 0, matrix.allSatisfy({ $0.count == count }) else {
            throw PerfusionEngineError.singularSystem
        }
        var augmented = matrix.enumerated().map { row, values in
            values + (0..<count).map { $0 == row ? 1.0 : 0.0 }
        }
        for pivot in 0..<count {
            let pivotRow = (pivot..<count).max { abs(augmented[$0][pivot]) < abs(augmented[$1][pivot]) } ?? pivot
            guard abs(augmented[pivotRow][pivot]) > 1e-14 else {
                throw PerfusionEngineError.singularSystem
            }
            if pivotRow != pivot { augmented.swapAt(pivot, pivotRow) }
            let divisor = augmented[pivot][pivot]
            for column in 0..<(2 * count) { augmented[pivot][column] /= divisor }
            for row in 0..<count where row != pivot {
                let factor = augmented[row][pivot]
                guard factor != 0 else { continue }
                for column in 0..<(2 * count) {
                    augmented[row][column] -= factor * augmented[pivot][column]
                }
            }
        }
        return augmented.map { Array($0[count..<(2 * count)]) }
    }
}
