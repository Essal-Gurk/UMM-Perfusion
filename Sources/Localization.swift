import Foundation

private final class PerfusionBundleMarker: NSObject {}

enum PerfusionLocalization {
    static let languages = ["en", "fr", "de", "es", "it", "pt", "ja", "zh-Hans", "tr", "ar"]
    static let bundle = Bundle(for: PerfusionBundleMarker.self)
    static let language = Bundle.preferredLocalizations(from: languages, forPreferences: Locale.preferredLanguages)
        .first ?? "en"
    static let localizedBundle = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    static let englishBundle = bundle.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
}

func L(_ key: String, _ arguments: any CustomStringConvertible...) -> String {
    let fallback = PerfusionLocalization.englishBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    let format = PerfusionLocalization.localizedBundle?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    guard !arguments.isEmpty else { return format }
    let locale = Locale(identifier: PerfusionLocalization.language)
    let values: [any CVarArg] = arguments.map { argument in
        if let integer = argument as? Int {
            return integer.formatted(.number.locale(locale))
        }
        return argument.description
    }
    return String(format: format, locale: locale, arguments: values)
}
