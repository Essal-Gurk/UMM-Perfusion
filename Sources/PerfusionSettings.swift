import Foundation

enum PerfusionMap: String, CaseIterable, Codable, Sendable, Identifiable {
    case ktrans, ve, vp, flow, volume, mtt, quality

    var id: String { rawValue }
    var localizationKey: String { "map." + rawValue }

    static func available(for model: PerfusionModel) -> [Self] {
        switch model {
        case .standardTofts: [.ktrans, .ve, .quality]
        case .extendedTofts: [.ktrans, .ve, .vp, .quality]
        case .deconvolution: [.flow, .volume, .mtt, .quality]
        }
    }

    func samples(from result: PerfusionMapResult) -> [Float] {
        switch self {
        case .ktrans, .flow: result.primary
        case .ve, .volume: result.secondary
        case .vp, .mtt: result.tertiary
        case .quality: result.quality
        }
    }
}

struct PerfusionSettings: Codable, Equatable {
    var model = PerfusionModel.standardTofts.rawValue
    var signalMode = PerfusionSignalMode.relativeT1.rawValue
    var baselineFrames = "3"
    var temporalResolution = "5.0"
    var hematocrit = "0.45"
    var regularization = "0.15"
    var lowSignalPercent = "1.0"
    var saveDICOM = false
    var mapsByModel: [String: [PerfusionMap]] = [:]

    func selectedMaps(for model: PerfusionModel) -> [PerfusionMap] {
        let selection = mapsByModel[model.rawValue]
            ?? (model == .deconvolution ? [.flow] : [.ktrans])
        return PerfusionMap.available(for: model).filter { selection.contains($0) }
    }

    static let defaultsKey = "settings.v1"

    static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(Self.self, from: data) else {
            return Self()
        }
        return settings
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
