import SwiftUI

struct PerfusionView: View {
    @ObservedObject var controller: PerfusionController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("title")).font(.largeTitle.bold())
                Text(L("research")).foregroundStyle(.secondary)
                source
                settings
                PerfusionStatusView(
                    message: controller.statusMessage, error: controller.errorMessage,
                    progress: controller.progress, saved: controller.savedCount, opened: controller.openedCount
                )
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(L("button.cancel")) { controller.cancel() }
                    .help(L("help.cancel"))
                    .disabled(!controller.isRunning || controller.isCancelling)
                Spacer()
                if controller.canRetryOpening {
                    Button(L("button.reopen")) { controller.retryOpening() }
                        .help(L("help.reopen"))
                }
                Button(L("button.run")) { controller.calculateAndExport() }
                    .help(L("help.calculate"))
                    .keyboardShortcut(.defaultAction)
                    .disabled(controller.isRunning || controller.phaseCount < 4 || controller.selectedMaps.isEmpty)
            }
            .padding(14)
            .background(.regularMaterial)
        }
        .frame(minWidth: 650, minHeight: 580)
        .environment(\.locale, Locale(identifier: PerfusionLocalization.language))
        .environment(\.layoutDirection, PerfusionLocalization.language == "ar" ? .rightToLeft : .leftToRight)
    }

    private var source: some View {
        GroupBox(L("section.source")) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                row(L("field.series"), controller.seriesDescription, help: L("help.series"))
                row(L("field.dimensions"), L("dimensions", controller.sliceCount, controller.phaseCount),
                    help: L("help.dimensions"))
                row(L("field.roi"), controller.selectedROIName, help: L("help.roi"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(L("button.refresh")) { controller.refresh() }
                .help(L("help.roi"))
                .disabled(controller.isRunning)
                .padding(.top, 8)
        }
    }

    private var settings: some View {
        GroupBox(L("section.model")) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    Text(L("field.model")).help(controller.model.helpText)
                    Picker(L("field.model"), selection: $controller.model) {
                        ForEach(PerfusionModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model).help(model.helpText)
                        }
                    }
                    .labelsHidden()
                    .help(controller.model.helpText)
                }
                GridRow {
                    Text(L("field.signal")).help(controller.signalMode.helpText)
                    Picker(L("field.signal"), selection: $controller.signalMode) {
                        ForEach(PerfusionSignalMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode).help(mode.helpText)
                        }
                    }
                    .labelsHidden()
                    .help(controller.signalMode.helpText)
                }
                input(L("field.baseline"), text: $controller.baselineFramesText, help: L("help.baseline"))
                input(L("field.interval"), text: $controller.temporalResolutionText, help: L("help.interval"))
                input(L("field.hct"), text: $controller.hematocritText, help: L("help.hct"))
                input(L("field.regularization"), text: $controller.regularizationText,
                      help: L("help.regularization"), enabled: controller.model == .deconvolution)
                input(L("field.threshold"), text: $controller.lowSignalPercentText, help: L("help.threshold"))
                GridRow {
                    Text(L("field.maps")).help(L("help.selection"))
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(PerfusionMap.available(for: controller.model)) { map in
                            Toggle(L(map.localizationKey), isOn: Binding(
                                get: { controller.selectedMaps.contains(map) },
                                set: { controller.setMap(map, selected: $0) }
                            ))
                            .toggleStyle(.checkbox)
                            .help(map.helpText)
                        }
                    }
                }
                GridRow {
                    Text(L("field.output")).help(L("help.output"))
                    Toggle(L("option.save"), isOn: $controller.saveDICOM)
                        .toggleStyle(.checkbox)
                        .help(L("help.output"))
                }
            }
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(controller.isRunning)
    }

    private func row(_ label: String, _ value: String, help: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).help(help)
            Text(value).textSelection(.enabled).help(help)
        }
    }

    private func input(_ label: String, text: Binding<String>, help: String, enabled: Bool = true) -> some View {
        GridRow {
            Text(label).help(help)
            TextField(label, text: text)
                .labelsHidden()
                .frame(idealWidth: 155, maxWidth: 210)
                .help(help)
                .disabled(!enabled)
        }
    }
}

private struct PerfusionStatusView: View {
    let message: String
    let error: String?
    let progress: Double?
    let saved: Int
    let opened: Int

    var body: some View {
        GroupBox(L("section.status")) {
            VStack(alignment: .leading, spacing: 8) {
                if let progress {
                    ProgressView(value: progress) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(message)
                            Spacer()
                            Text(progress, format: .percent.precision(.fractionLength(0)).rounded(rule: .down))
                                .monospacedDigit()
                        }
                    }
                    .help(L("help.progress"))
                    Text(L("results.count", saved, opened))
                        .foregroundStyle(.secondary)
                        .help(L("help.output"))
                } else {
                    Text(message)
                }
                if let error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension PerfusionModel {
    var helpText: String {
        switch self {
        case .standardTofts: L("help.standard")
        case .extendedTofts: L("help.extended")
        case .deconvolution: L("help.deconvolution")
        }
    }

    var displayName: String {
        switch self {
        case .standardTofts: L("model.standard")
        case .extendedTofts: L("model.extended")
        case .deconvolution: L("model.deconvolution")
        }
    }

}

private extension PerfusionSignalMode {
    var helpText: String {
        switch self {
        case .relativeT1: L("help.relative")
        case .absoluteT1: L("help.absolute")
        case .relativeT2Star: L("help.dsc")
        }
    }

    var displayName: String {
        switch self {
        case .relativeT1: L("signal.relative")
        case .absoluteT1: L("signal.absolute")
        case .relativeT2Star: L("signal.dsc")
        }
    }
}

private extension PerfusionMap {
    var helpText: String {
        switch self {
        case .ktrans: L("help.ktrans")
        case .ve: L("help.ve")
        case .vp: L("help.vp")
        case .flow: L("help.flow")
        case .volume: L("help.volume")
        case .mtt: L("help.mtt")
        case .quality: L("help.quality")
        }
    }
}
