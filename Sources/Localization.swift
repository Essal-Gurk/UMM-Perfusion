import Foundation

private final class PerfusionBundleMarker: NSObject {}

enum PerfusionLocalization {
    static let languages = ["en", "fr", "de", "es", "it", "pt", "ja", "zh-Hans", "tr", "ar"]
    static let bundle = Bundle(for: PerfusionBundleMarker.self)
    static let defaults = UserDefaults(suiteName: "org.umm-perfusion.isix.native")!
    static let preferenceKey = "language.v1"
    static var preference: String {
        get { defaults.string(forKey: preferenceKey) ?? "system" }
        set { defaults.set(newValue == "system" || languages.contains(newValue) ? newValue : "system",
                           forKey: preferenceKey) }
    }
    static func resolvedLanguage(for preference: String, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if languages.contains(preference) { return preference }
        return Bundle.preferredLocalizations(from: languages, forPreferences: preferredLanguages).first ?? "en"
    }
    static var language: String { resolvedLanguage(for: preference) }
    static let localizedBundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: languages.compactMap { code in
        guard let path = bundle.path(forResource: code, ofType: "lproj"), let localized = Bundle(path: path) else {
            return nil
        }
        return (code, localized)
    })
    static let englishBundle = bundle.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))

    static func text(_ key: String, language: String) -> String {
        let fallback = englishBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
        return localizedBundles[language]?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    }

    static func nativeName(for language: String) -> String {
        switch language {
        case "en": "English"
        case "de": "Deutsch"
        case "fr": "Français"
        case "es": "Español"
        case "it": "Italiano"
        case "pt": "Português"
        case "ja": "日本語"
        case "zh-Hans": "简体中文"
        case "tr": "Türkçe"
        case "ar": "العربية"
        default: language
        }
    }
}

func L(_ key: String, _ arguments: any CustomStringConvertible...) -> String {
    let language = PerfusionLocalization.language
    let format = PerfusionLocalization.text(key, language: language)
    guard !arguments.isEmpty else { return format }
    let locale = Locale(identifier: language)
    let values: [any CVarArg] = arguments.map { argument in
        if let integer = argument as? Int {
            return integer.formatted(.number.locale(locale))
        }
        return argument.description
    }
    return String(format: format, locale: locale, arguments: values)
}

// Store keys and typed arguments for messages that must survive language changes.
indirect enum PerfusionText: Sendable, Equatable {
    case message(String, [PerfusionText])
    case literal(String)
    case integer(Int)

    func rendered(language: String = PerfusionLocalization.language) -> String {
        switch self {
        case .literal(let value): return value
        case .integer(let value): return value.formatted(.number.locale(Locale(identifier: language)))
        case .message(let key, let arguments):
            let format = PerfusionLocalization.text(key, language: language)
            guard !arguments.isEmpty else { return format }
            return String(format: format, locale: Locale(identifier: language),
                          arguments: arguments.map { $0.rendered(language: language) as any CVarArg })
        }
    }
}

protocol PerfusionTextArgument {
    var perfusionText: PerfusionText { get }
}
extension String: PerfusionTextArgument {
    var perfusionText: PerfusionText { .literal(self) }
}
extension Int: PerfusionTextArgument {
    var perfusionText: PerfusionText { .integer(self) }
}
extension PerfusionText: PerfusionTextArgument {
    var perfusionText: PerfusionText { self }
}
func T(_ key: String, _ arguments: any PerfusionTextArgument...) -> PerfusionText {
    .message(key, arguments.map(\.perfusionText))
}
