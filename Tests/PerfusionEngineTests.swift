import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let message): return message }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.failed(message) }
}

private func expectNear(_ actual: Double, _ expected: Double, tolerance: Double, _ message: String) throws {
    if abs(actual - expected) > tolerance {
        throw TestFailure.failed("\(message): expected \(expected), got \(actual)")
    }
}

@main
enum PerfusionEngineTests {
    static func main() throws {
        try signalConversion()
        try standardToftsRecovery()
        try extendedToftsRecovery()
        try deconvolutionProducesFiniteParameters()
        try lowSignalMasking()
        try mapProgressAndCancellation()
        try invalidTimingRejected()
        try savedSettingsAndMapSelection()
        print("PerfusionEngineTests: all tests passed")
    }

    private static let timesSeconds = (0..<24).map { Double($0) * 5 }

    private static func savedSettingsAndMapSelection() throws {
        var settings = PerfusionSettings()
        try expect(settings.selectedMaps(for: .extendedTofts) == [.ktrans], "Default must select Ktrans only")
        try expect(!settings.saveDICOM, "Default must open in-memory results")
        settings.model = PerfusionModel.extendedTofts.rawValue
        settings.saveDICOM = true
        settings.hematocrit = "0,42"
        settings.mapsByModel[PerfusionModel.extendedTofts.rawValue] = [.vp, .ktrans]
        settings.mapsByModel[PerfusionModel.standardTofts.rawValue] = [.ve]
        settings.mapsByModel[PerfusionModel.deconvolution.rawValue] = []
        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(PerfusionSettings.self, from: data)
        try expect(restored == settings, "Settings must survive persistence")
        try expect(restored.selectedMaps(for: .extendedTofts) == [.ktrans, .vp], "Map order must match output order")
        try expect(restored.selectedMaps(for: .standardTofts) == [.ve], "Each model needs its own selection")
        try expect(restored.selectedMaps(for: .deconvolution).isEmpty, "Empty selection must survive persistence")
        let result = PerfusionMapResult(primary: [0.42], secondary: [36], tertiary: [7],
                                       quality: [0.99], invalidVoxelCount: 0)
        try expect(PerfusionMap.ktrans.samples(from: result) == [0.42], "Ktrans must use the primary map")
        try expect(PerfusionMap.vp.samples(from: result) == [7], "vp must use the tertiary map")
        try expect(PerfusionMap.quality.samples(from: result) == [0.99], "R2 must use the quality map")
    }
    private static let timesMinutes = timesSeconds.map { $0 / 60 }
    private static let plasmaConcentration: [Double] = timesSeconds.map { time in
        guard time >= 15 else { return 0 }
        let shifted = time - 15
        return 4.0 * (shifted / 10) * exp(-shifted / 14)
    }

    private static func rawSignal(from concentration: [Double]) -> [Double] {
        concentration.map { 1_000 * (1 + $0) }
    }

    private static func configuration(model: PerfusionModel) -> PerfusionConfiguration {
        PerfusionConfiguration(
            model: model,
            signalMode: .relativeT1,
            baselineFrames: 3,
            hematocrit: 0,
            regularization: 0.1,
            lowSignalFraction: 0.01
        )
    }

    private static func signalConversion() throws {
        let signal = [100.0, 100, 120, 150]
        let relative = try PerfusionEngine.concentration(signal: signal, baselineFrames: 2, mode: .relativeT1)
        try expectNear(relative[2], 0.2, tolerance: 1e-12, "Relative T1 conversion")
        let t2 = try PerfusionEngine.concentration(signal: [100, 100, 80], baselineFrames: 2, mode: .relativeT2Star)
        try expectNear(t2[2], -log(0.8), tolerance: 1e-12, "T2* conversion")
    }

    private static func standardToftsRecovery() throws {
        let tissue = PerfusionEngine.simulateTofts(
            aif: plasmaConcentration,
            timesMinutes: timesMinutes,
            kTrans: 0.42,
            ve: 0.36
        )
        let config = configuration(model: .standardTofts)
        let prepared = try PerfusionEngine.prepare(
            aifSignal: rawSignal(from: plasmaConcentration),
            timesSeconds: timesSeconds,
            configuration: config
        )
        let fit = PerfusionEngine.fit(signal: rawSignal(from: tissue), prepared: prepared, configuration: config)
        try expect(fit.isValid, "Standard Tofts fit was invalid")
        try expectNear(fit.primary, 0.42, tolerance: 0.06, "Standard Tofts Ktrans")
        try expectNear(fit.secondary, 36, tolerance: 6, "Standard Tofts ve")
        try expect(fit.rSquared > 0.98, "Standard Tofts R2 was too low")
    }

    private static func extendedToftsRecovery() throws {
        let tissue = PerfusionEngine.simulateTofts(
            aif: plasmaConcentration,
            timesMinutes: timesMinutes,
            kTrans: 0.31,
            ve: 0.28,
            vp: 0.07
        )
        let config = configuration(model: .extendedTofts)
        let prepared = try PerfusionEngine.prepare(
            aifSignal: rawSignal(from: plasmaConcentration),
            timesSeconds: timesSeconds,
            configuration: config
        )
        let fit = PerfusionEngine.fit(signal: rawSignal(from: tissue), prepared: prepared, configuration: config)
        try expect(fit.isValid, "Extended Tofts fit was invalid")
        try expectNear(fit.primary, 0.31, tolerance: 0.06, "Extended Tofts Ktrans")
        try expectNear(fit.secondary, 28, tolerance: 7, "Extended Tofts ve")
        try expectNear(fit.tertiary, 7, tolerance: 2, "Extended Tofts vp")
        try expect(fit.rSquared > 0.98, "Extended Tofts R2 was too low")
    }

    private static func deconvolutionProducesFiniteParameters() throws {
        let tissue = PerfusionEngine.simulateTofts(
            aif: plasmaConcentration,
            timesMinutes: timesMinutes,
            kTrans: 0.5,
            ve: 0.4
        )
        let config = configuration(model: .deconvolution)
        let prepared = try PerfusionEngine.prepare(
            aifSignal: rawSignal(from: plasmaConcentration),
            timesSeconds: timesSeconds,
            configuration: config
        )
        let fit = PerfusionEngine.fit(signal: rawSignal(from: tissue), prepared: prepared, configuration: config)
        try expect(fit.isValid, "Deconvolution fit was invalid")
        try expect(fit.primary.isFinite && fit.primary > 0, "Plasma flow must be finite and positive")
        try expect(fit.secondary.isFinite && fit.secondary > 0, "Plasma volume must be finite and positive")
        try expect(fit.tertiary.isFinite && fit.tertiary > 0, "MTT must be finite and positive")
    }

    private static func lowSignalMasking() throws {
        let config = configuration(model: .standardTofts)
        let validSignal = rawSignal(from: PerfusionEngine.simulateTofts(
            aif: plasmaConcentration,
            timesMinutes: timesMinutes,
            kTrans: 0.4,
            ve: 0.35
        ))
        let planes = validSignal.map { [Float($0), 0.1] }
        let result = try PerfusionEngine.fitMap(
            signalPlanes: planes,
            aifSignal: rawSignal(from: plasmaConcentration),
            timesSeconds: timesSeconds,
            configuration: config
        )
        try expect(result.invalidVoxelCount == 1, "Low-signal background voxel was not masked")
        try expect(result.primary[1] == 0, "Masked map value must be zero")
    }

    private static func invalidTimingRejected() throws {
        do {
            try PerfusionEngine.validate(times: [0, 5, 5, 10, 15], configuration: configuration(model: .standardTofts))
            throw TestFailure.failed("Non-monotonic timing was accepted")
        } catch PerfusionEngineError.invalidTimes {
            return
        }
    }

    private static func mapProgressAndCancellation() throws {
        let config = configuration(model: .standardTofts)
        let prepared = try PerfusionEngine.prepare(
            aifSignal: rawSignal(from: plasmaConcentration),
            timesSeconds: timesSeconds,
            configuration: config
        )
        let tissue = PerfusionEngine.simulateTofts(
            aif: plasmaConcentration, timesMinutes: timesMinutes, kTrans: 0.42, ve: 0.36
        )
        let planes = rawSignal(from: tissue).map { [Float($0), 0, Float($0)] }
        var processed: [Int] = []
        let result = try PerfusionEngine.fitMap(signalPlanes: planes, prepared: prepared, configuration: config) {
            done, total in
            try expect(total == 3, "Progress total must include masked voxels")
            processed.append(done)
        }
        try expect(processed == [0, 1, 2, 3], "Progress must advance through every batch")
        try expect(result.invalidVoxelCount == 1, "Masked voxel count changed")

        do {
            _ = try PerfusionEngine.fitMap(signalPlanes: planes, prepared: prepared, configuration: config) { done, _ in
                if done == 1 { throw CancellationError() }
            }
            throw TestFailure.failed("Fit ignored cancellation")
        } catch is CancellationError {
            return
        }
    }
}
