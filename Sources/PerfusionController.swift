import Foundation
import Combine
import IsiXPluginKit

private struct PerfusionInput: Sendable {
    let summary: IsiXSeriesSummary
    let studyUID: String
    let sourceSOPUID: String?
    let aif: [Double]
    let times: [Double]
    let usesDICOMTimes: Bool
    let roiName: String
}

enum PerfusionPluginError: LocalizedError {
    case invalidInput(String)
    case stage(String, any Error)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message): return message
        case .stage(let stage, let error):
            let detail = (error as? PerfusionEngineError)?.displayMessage ?? error.localizedDescription
            return L("error.stage", stage, detail)
        }
    }
}

private extension PerfusionEngineError {
    var displayMessage: String {
        switch self {
        case .insufficientTimepoints: L("error.phases")
        case .invalidBaseline: L("error.baseline")
        case .invalidTimes: L("error.times")
        case .countMismatch: L("error.count")
        case .singularSystem: L("error.singular")
        case .invalidConfiguration: L("error.config")
        }
    }
}

@MainActor
final class PerfusionController: ObservableObject {
    private let context: IsiXPluginContext
    private var viewer: IsiXViewer
    private var currentTask: IsiXTask?
    private var pendingViewers: [String] = []
    private let defaults = UserDefaults(suiteName: "org.umm-perfusion.isix.native")!

    @Published private(set) var seriesDescription = ""
    @Published private(set) var sliceCount = 0
    @Published private(set) var phaseCount = 0
    @Published private(set) var selectedROIName = L("roi.none")
    @Published private(set) var statusMessage = L("status.ready")
    @Published private(set) var errorMessage: String?
    @Published private(set) var progress: Double?
    @Published private(set) var savedCount = 0
    @Published private(set) var openedCount = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isCancelling = false
    @Published private(set) var canRetryOpening = false
    @Published private(set) var languageChoice = PerfusionLocalization.preference

    func changeLanguage(to choice: String) {
        guard !isRunning else { return }
        let oldLanguage = PerfusionLocalization.language
        let statusKeys = ["status.ready", "status.cancelled", "status.failed", "status.dicom",
                          "status.manual", "status.opened", "stage.aif"]
        let statusKey = statusKeys.first {
            PerfusionLocalization.text($0, language: oldLanguage) == statusMessage
        }
        PerfusionLocalization.preference = choice
        languageChoice = PerfusionLocalization.preference
        if let statusKey { statusMessage = L(statusKey) }
        refresh()
    }

    @Published var model: PerfusionModel = .standardTofts { didSet { persistSettings() } }
    @Published var signalMode: PerfusionSignalMode = .relativeT1 { didSet { persistSettings() } }
    @Published var baselineFramesText = "3" { didSet { persistSettings() } }
    @Published var temporalResolutionText = "5.0" { didSet { persistSettings() } }
    @Published var hematocritText = "0.45" { didSet { persistSettings() } }
    @Published var regularizationText = "0.15" { didSet { persistSettings() } }
    @Published var lowSignalPercentText = "1.0" { didSet { persistSettings() } }
    @Published var saveDICOM = false { didSet { persistSettings() } }
    @Published private var mapsByModel: [String: [PerfusionMap]] = [:] { didSet { persistSettings() } }

    var selectedMaps: [PerfusionMap] {
        settings.selectedMaps(for: model)
    }

    func setMap(_ map: PerfusionMap, selected: Bool) {
        var selection = selectedMaps
        selection.removeAll { $0 == map }
        if selected { selection.append(map) }
        mapsByModel[model.rawValue] = selection
    }

    private var settings: PerfusionSettings {
        var value = PerfusionSettings()
        value.model = model.rawValue
        value.signalMode = signalMode.rawValue
        value.baselineFrames = baselineFramesText
        value.temporalResolution = temporalResolutionText
        value.hematocrit = hematocritText
        value.regularization = regularizationText
        value.lowSignalPercent = lowSignalPercentText
        value.saveDICOM = saveDICOM
        value.mapsByModel = mapsByModel
        return value
    }

    private func persistSettings() {
        settings.save(to: defaults)
    }

    init(context: IsiXPluginContext, viewer: IsiXViewer) {
        self.context = context
        self.viewer = viewer
        let saved = PerfusionSettings.load(from: defaults)
        model = PerfusionModel(rawValue: saved.model) ?? .standardTofts
        signalMode = PerfusionSignalMode(rawValue: saved.signalMode) ?? .relativeT1
        baselineFramesText = saved.baselineFrames
        temporalResolutionText = saved.temporalResolution
        hematocritText = saved.hematocrit
        regularizationText = saved.regularization
        lowSignalPercentText = saved.lowSignalPercent
        saveDICOM = saved.saveDICOM
        mapsByModel = saved.mapsByModel
        refresh()
    }

    func connect(to viewer: IsiXViewer) {
        guard !isRunning else { return }
        self.viewer = viewer
        refresh()
    }

    func refresh() {
        guard !isRunning else { return }
        do {
            guard viewer.isOpen else { throw PerfusionPluginError.invalidInput(L("error.viewer")) }
            let summary = try viewer.series()
            seriesDescription = summary.seriesDescription ?? L("series.unnamed")
            sliceCount = summary.sliceCount
            phaseCount = summary.phaseCount
            let position = try viewer.currentPosition()
            let rois = try viewer.rois(slice: position.slice, phase: position.phase)
            selectedROIName = Self.arterialROI(in: rois).map {
                $0.name.isEmpty ? L("roi.unnamed") : $0.name
            } ?? L("roi.none")
            if progress == nil {
                statusMessage = L("status.ready")
                errorMessage = nil
            }
        } catch {
            phaseCount = 0
            errorMessage = error.localizedDescription
        }
    }

    func calculateAndExport() {
        guard !isRunning else { return }
        progress = 0
        errorMessage = nil
        savedCount = 0
        openedCount = 0
        pendingViewers.removeAll()
        canRetryOpening = false
        statusMessage = L("stage.aif")
        do {
            let (configuration, fallbackDelta) = try parseSettings()
            let selection = selectedMaps
            guard !selection.isEmpty else {
                throw PerfusionPluginError.invalidInput(L("error.selection"))
            }
            let shouldSave = saveDICOM
            let source = viewer
            let job = try context.startTask(named: L("title")) { [weak self, context] progress in
                try Self.checkCancellation(progress)
                progress.report(0, message: L("stage.aif"))
                let input = try await Self.captureInput(
                    viewer: source, fallbackDelta: fallbackDelta, requiresStudy: shouldSave, progress: progress
                )
                await self?.showInput(input)
                progress.report(0.04, message: L("stage.prepare"))
                let prepared = try PerfusionEngine.prepare(
                    aifSignal: input.aif, timesSeconds: input.times, configuration: configuration
                )
                let maps = try await Self.compute(
                    viewer: source, input: input, configuration: configuration, prepared: prepared,
                    selection: selection, progress: progress
                )
                if shouldSave {
                    try await Self.save(
                        maps, model: configuration.model, input: input, context: context, progress: progress
                    ) { [weak self] uid in
                        self?.savedCount += 1
                        self?.pendingViewers.append(uid)
                    }
                    try Self.checkCancellation(progress)
                    progress.report(0.98, message: L("stage.open"))
                    await self?.openSavedResults()
                } else {
                    try await Self.showInMemory(
                        maps, model: configuration.model, viewer: source, input: input, progress: progress
                    ) { [weak self] in
                        self?.openedCount += 1
                    }
                }
                progress.report(1, message: input.usesDICOMTimes ? L("status.dicom") : L("status.manual"))
            }
            currentTask = job
            isRunning = true
            Task { [weak self] in
                while !job.isFinished, self != nil {
                    self?.updateProgress(job)
                    try? await Task.sleep(for: .milliseconds(120))
                }
                guard let self else { return }
                self.updateProgress(job)
                do {
                    try await job.value()
                    if self.isCancelling, job.progress.fractionCompleted < 1 {
                        throw CancellationError()
                    }
                } catch {
                    let stage = job.progress.message ?? self.statusMessage
                    if error is CancellationError || self.isCancelling || job.progress.isCancelled {
                        self.statusMessage = L("status.cancelled")
                    } else {
                        self.statusMessage = L("status.failed")
                        self.errorMessage = (error as? PerfusionPluginError)?.errorDescription
                            ?? PerfusionPluginError.stage(stage, error).localizedDescription
                    }
                }
                self.currentTask = nil
                self.isRunning = false
                self.isCancelling = false
                self.canRetryOpening = !self.pendingViewers.isEmpty
            }
        } catch {
            statusMessage = L("status.failed")
            errorMessage = error.localizedDescription
        }
    }

    private func updateProgress(_ job: IsiXTask) {
        let fraction = job.progress.fractionCompleted
        if fraction != progress { progress = fraction }
        if !isCancelling, let message = job.progress.message, message != statusMessage {
            statusMessage = message
        }
    }

    private func showInput(_ input: PerfusionInput) {
        seriesDescription = input.summary.seriesDescription ?? L("series.unnamed")
        sliceCount = input.summary.sliceCount
        phaseCount = input.summary.phaseCount
        selectedROIName = input.roiName
    }

    func cancel() {
        guard isRunning, !isCancelling else { return }
        isCancelling = true
        statusMessage = L("status.cancelling")
        currentTask?.cancel()
    }

    func retryOpening() {
        guard !isRunning, canRetryOpening else { return }
        errorMessage = nil
        openSavedResults()
        canRetryOpening = !pendingViewers.isEmpty
        if !canRetryOpening { statusMessage = L("status.opened") }
    }

    private func openSavedResults() {
        do {
            let database = try context.database()
            var failed: [String] = []
            for uid in pendingViewers {
                do {
                    guard try database.openViewer(forSeries: uid) != nil else {
                        failed.append(uid)
                        continue
                    }
                    openedCount += 1
                } catch {
                    failed.append(uid)
                }
            }
            pendingViewers = failed
            if !failed.isEmpty { errorMessage = L("error.open", failed.count) }
        } catch {
            errorMessage = PerfusionPluginError.stage(L("stage.open"), error).localizedDescription
        }
    }

    private func parseSettings() throws -> (PerfusionConfiguration, Double) {
        func number(_ value: String, key: String) throws -> Double {
            guard let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")), parsed.isFinite else {
                throw PerfusionPluginError.invalidInput(L("error.number", L(key)))
            }
            return parsed
        }
        guard let baseline = Int(baselineFramesText.trimmingCharacters(in: .whitespacesAndNewlines)),
              baseline > 0 else {
            throw PerfusionPluginError.invalidInput(L("error.baseline"))
        }
        let delta = try number(temporalResolutionText, key: "field.interval")
        let hct = try number(hematocritText, key: "field.hct")
        let regularization = model == .deconvolution
            ? try number(regularizationText, key: "field.regularization") : 0.15
        let threshold = try number(lowSignalPercentText, key: "field.threshold")
        guard delta > 0 else { throw PerfusionPluginError.invalidInput(L("error.interval")) }
        guard (0..<0.9).contains(hct) else {
            throw PerfusionPluginError.invalidInput(L("error.hct"))
        }
        guard regularization > 0, regularization <= 1 else {
            throw PerfusionPluginError.invalidInput(L("error.regularization"))
        }
        guard (0...100).contains(threshold) else {
            throw PerfusionPluginError.invalidInput(L("error.threshold"))
        }
        return (PerfusionConfiguration(model: model, signalMode: signalMode, baselineFrames: baseline,
            hematocrit: hct, regularization: regularization, lowSignalFraction: threshold / 100), delta)
    }

    private static func arterialROI(in rois: [IsiXROI]) -> IsiXROI? {
        let candidates = rois.filter { [.oval, .rectangle, .polygon, .brush].contains($0.kind) }
        let selected = candidates.filter(\.isSelected)
        if selected.count == 1 { return selected.first }
        return selected.isEmpty && candidates.count == 1 ? candidates.first : nil
    }

    private static func captureInput(
        viewer: IsiXViewer, fallbackDelta: Double, requiresStudy: Bool, progress: IsiXTaskProgress
    ) throws -> PerfusionInput {
        guard viewer.isOpen else { throw PerfusionPluginError.invalidInput(L("error.viewer")) }
        let summary = try viewer.series()
        guard summary.phaseCount >= 4, summary.sliceCount > 0 else {
            throw PerfusionPluginError.invalidInput(L("error.phases"))
        }
        let position = try viewer.currentPosition()
        guard let roi = arterialROI(in: try viewer.rois(slice: position.slice, phase: position.phase)) else {
            throw PerfusionPluginError.invalidInput(L("error.roi"))
        }
        let reference = try viewer.attributes(slice: 0, phase: 0)
        let studyUID = summary.studyInstanceUID ?? reference.studyInstanceUID ?? ""
        if requiresStudy, studyUID.isEmpty { throw PerfusionPluginError.invalidInput(L("error.study")) }
        let geometry = try viewer.geometry(slice: roi.slice, phase: roi.phase)
        var aif: [Double] = []
        var dates: [Date?] = []
        for phase in 0..<summary.phaseCount {
            try checkCancellation(progress)
            progress.report(0.04 * Double(phase) / Double(summary.phaseCount), message: L("stage.aif"))
            guard geometryMatches(geometry, try viewer.geometry(slice: roi.slice, phase: phase)) else {
                throw PerfusionPluginError.invalidInput(L("error.geometry", roi.slice + 1, phase + 1))
            }
            do {
                aif.append(try viewer.statistics(of: roi.id, slice: roi.slice, phase: phase).mean)
            } catch {
                throw PerfusionPluginError.stage(L("error.aifPhase", phase + 1), error)
            }
            dates.append(try? viewer.attributes(slice: roi.slice, phase: phase).acquisitionDate)
        }
        guard aif.allSatisfy(\.isFinite), aif.min() != aif.max() else {
            throw PerfusionPluginError.invalidInput(L("error.aifSignal"))
        }
        let timestamps = dates.compactMap { $0 }
        let roiName = roi.name.isEmpty ? L("roi.unnamed") : roi.name
        if timestamps.count == dates.count, let origin = timestamps.first {
            let times = timestamps.map { $0.timeIntervalSince(origin) }
            if zip(times.dropFirst(), times).allSatisfy({ $0.0 > $0.1 }) {
                return PerfusionInput(summary: summary, studyUID: studyUID, sourceSOPUID: reference.sopInstanceUID,
                    aif: aif, times: times, usesDICOMTimes: true, roiName: roiName)
            }
        }
        let times = dates.indices.map { Double($0) * fallbackDelta }
        return PerfusionInput(summary: summary, studyUID: studyUID, sourceSOPUID: reference.sopInstanceUID,
            aif: aif, times: times, usesDICOMTimes: false, roiName: roiName)
    }

    private static func readSlice(
        _ slice: Int, viewer: IsiXViewer, input: PerfusionInput, progress: IsiXTaskProgress
    ) throws -> (IsiXImageGeometry, [[Float]]) {
        try checkCancellation(progress)
        guard viewer.isOpen else { throw PerfusionPluginError.invalidInput(L("error.viewer")) }
        let current = try viewer.series()
        guard current.seriesInstanceUID == input.summary.seriesInstanceUID,
              current.studyInstanceUID == input.summary.studyInstanceUID,
              current.sliceCount == input.summary.sliceCount, current.phaseCount == input.summary.phaseCount,
              try viewer.attributes(slice: 0, phase: 0).sopInstanceUID == input.sourceSOPUID else {
            throw PerfusionPluginError.invalidInput(L("error.changed"))
        }
        let geometry = try viewer.geometry(slice: slice, phase: 0)
        var planes: [[Float]] = []
        for phase in 0..<current.phaseCount {
            try checkCancellation(progress)
            let image = try viewer.image(slice: slice, phase: phase)
            guard let pixels = image.scalarPixels, pixels.channels == 1 else {
                throw PerfusionPluginError.invalidInput(L("error.scalar", slice + 1, phase + 1))
            }
            guard geometryMatches(geometry, image.geometry),
                  pixels.width == geometry.columns, pixels.height == geometry.rows else {
                throw PerfusionPluginError.invalidInput(L("error.geometry", slice + 1, phase + 1))
            }
            planes.append(pixels.samples)
        }
        return (geometry, planes)
    }

    private struct Maps: Sendable {
        let selection: [PerfusionMap]
        var images: [[IsiXPixelData]]
        var geometries: [IsiXImageGeometry] = []
    }

    nonisolated private static func compute(
        viewer: IsiXViewer, input: PerfusionInput, configuration: PerfusionConfiguration,
        prepared: PerfusionEngine.PreparedModel, selection: [PerfusionMap], progress: IsiXTaskProgress
    ) async throws -> Maps {
        var maps = Maps(selection: selection, images: Array(repeating: [], count: selection.count))
        let count = input.summary.sliceCount
        var validVoxels = 0
        for slice in 0..<count {
            let start = 0.04 + 0.76 * Double(slice) / Double(count)
            let step = 0.76 / Double(count)
            progress.report(start, message: L("stage.read", slice + 1, count))
            let (geometry, planes) = try await readSlice(slice, viewer: viewer, input: input, progress: progress)
            let message = L("stage.fit", slice + 1, count)
            let result = try PerfusionEngine.fitMap(signalPlanes: planes, prepared: prepared, configuration: configuration) {
                done, total in
                try checkCancellation(progress)
                progress.report(start + step * (0.1 + 0.9 * Double(done) / Double(total)), message: message)
            }
            validVoxels += result.primary.count - result.invalidVoxelCount
            maps.geometries.append(geometry)
            let samples = selection.map { $0.samples(from: result) }
            for index in samples.indices {
                let buffer = try IsiXPixelBuffer(width: geometry.columns, height: geometry.rows, samples: samples[index])
                maps.images[index].append(.float32(buffer))
            }
        }
        guard validVoxels > 0 else { throw PerfusionPluginError.invalidInput(L("error.noFit")) }
        return maps
    }

    private static func save(
        _ maps: Maps, model: PerfusionModel, input: PerfusionInput, context: IsiXPluginContext,
        progress: IsiXTaskProgress, didSave: @MainActor @Sendable (String) -> Void
    ) async throws {
        try checkCancellation(progress)
        let database = try context.database()
        let definitions = mapDefinitions(for: model).filter { maps.selection.map(\.localizationKey).contains($0.key) }
        for (index, map) in definitions.enumerated() {
            try checkCancellation(progress)
            let start = 0.80 + 0.18 * Double(index) / Double(definitions.count)
            let name = L(map.key)
            let writing = L("stage.write", name)
            progress.report(start, message: writing)
            var request = IsiXDerivedSeriesRequest(studyInstanceUID: input.studyUID,
                seriesDescription: "UMM Perfusion - \(map.dicomName)", images: maps.images[index])
            request.sourceSOPInstanceUID = input.sourceSOPUID
            request.geometries = maps.geometries
            request.windowLevel = map.window
            let files: [URL]
            do {
                files = try await database.writeDerivedSeries(request)
            } catch {
                throw PerfusionPluginError.stage(writing, error)
            }
            defer { removeTemporaryFiles(files) }
            guard files.count == maps.geometries.count else {
                throw PerfusionPluginError.invalidInput(L("error.write", name))
            }
            try checkCancellation(progress)
            let importing = L("stage.import", name)
            progress.report(start + 0.09 / Double(definitions.count), message: importing)
            let result: IsiXImportResult
            do {
                result = try await database.importFiles(at: files)
            } catch {
                throw PerfusionPluginError.stage(importing, error)
            }
            let series = Set(result.seriesInstanceUIDs)
            guard result.failures.isEmpty, result.importedFiles.count == files.count,
                  series.count == 1, let uid = series.first, !uid.isEmpty else {
                let message = L("error.import", name, result.importedFiles.count, files.count)
                let detail = result.failures.first?.reason
                throw PerfusionPluginError.invalidInput(detail.map { L("error.stage", message, $0) } ?? message)
            }
            didSave(uid)
        }
    }

    private static func showInMemory(
        _ maps: Maps, model: PerfusionModel, viewer: IsiXViewer, input: PerfusionInput,
        progress: IsiXTaskProgress, didOpen: @MainActor @Sendable () -> Void
    ) throws {
        guard viewer.isOpen else { throw PerfusionPluginError.invalidInput(L("error.viewer")) }
        let summary = try viewer.series()
        guard summary.seriesInstanceUID == input.summary.seriesInstanceUID,
              summary.studyInstanceUID == input.summary.studyInstanceUID,
              summary.sliceCount == input.summary.sliceCount, summary.phaseCount == input.summary.phaseCount,
              try viewer.attributes(slice: 0, phase: 0).sopInstanceUID == input.sourceSOPUID else {
            throw PerfusionPluginError.invalidInput(L("error.changed"))
        }
        let definitions = mapDefinitions(for: model).filter { maps.selection.map(\.localizationKey).contains($0.key) }
        for (index, definition) in definitions.enumerated() {
            try checkCancellation(progress)
            progress.report(0.80 + 0.19 * Double(index) / Double(definitions.count),
                            message: L("stage.preview", L(definition.key)))
            let images = try maps.images[index].enumerated().map { slice, pixels in
                guard case .float32(let buffer) = pixels else {
                    throw PerfusionPluginError.invalidInput(L("error.count"))
                }
                return IsiXDerivedImage(sourceSlice: slice, sourcePhase: 0, pixels: buffer)
            }
            _ = try viewer.openDerivedSeries(IsiXDerivedSeries(images: images, windowLevel: definition.window))
            didOpen()
        }
    }

    private struct MapDefinition {
        let key: String
        let dicomName: String
        let window: IsiXWindowLevel

        init(_ key: String, _ dicomName: String, _ center: Double, _ width: Double) {
            self.key = key
            self.dicomName = dicomName
            self.window = IsiXWindowLevel(center: center, width: width)
        }
    }

    nonisolated private static func mapDefinitions(for model: PerfusionModel) -> [MapDefinition] {
        let quality = MapDefinition("map.quality", "Fit quality R2", 0.5, 1)
        let ktrans = MapDefinition("map.ktrans", "Ktrans [1/min]", 0.5, 1)
        let ve = MapDefinition("map.ve", "ve [%]", 50, 100)
        switch model {
        case .standardTofts: return [ktrans, ve, quality]
        case .extendedTofts: return [ktrans, ve, MapDefinition("map.vp", "vp [%]", 50, 100), quality]
        case .deconvolution:
            return [MapDefinition("map.flow", "Plasma flow [mL/100mL/min]", 250, 500),
                    MapDefinition("map.volume", "Plasma volume [%]", 10, 20),
                    MapDefinition("map.mtt", "MTT [s]", 15, 30), quality]
        }
    }

    nonisolated private static func checkCancellation(_ progress: IsiXTaskProgress) throws {
        if progress.isCancelled { throw CancellationError() }
        try Task.checkCancellation()
    }

    nonisolated private static func removeTemporaryFiles(_ files: [URL]) {
        let manager = FileManager.default
        for file in files { try? manager.removeItem(at: file) }
        for directory in Set(files.map { $0.deletingLastPathComponent() }) {
            if (try? manager.contentsOfDirectory(atPath: directory.path))?.isEmpty == true {
                try? manager.removeItem(at: directory)
            }
        }
    }

    nonisolated private static func geometryMatches(_ lhs: IsiXImageGeometry, _ rhs: IsiXImageGeometry) -> Bool {
        lhs.columns == rhs.columns && lhs.rows == rhs.rows
            && abs(lhs.columnSpacing - rhs.columnSpacing) <= 0.0001
            && abs(lhs.rowSpacing - rhs.rowSpacing) <= 0.0001
            && (lhs.imagePosition - rhs.imagePosition).length <= 0.05
            && (lhs.rowDirection - rhs.rowDirection).length <= 0.0001
            && (lhs.columnDirection - rhs.columnDirection).length <= 0.0001
    }
}
