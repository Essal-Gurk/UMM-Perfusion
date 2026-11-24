import Foundation

@main
enum LocalizationTests {
    static func main() throws {
        let preferences = PerfusionLocalization.defaults
        let previous = preferences.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { preferences.setVolatileDomain(previous, forName: UserDefaults.argumentDomain) }

        precondition(PerfusionLocalization.languages.count == 10)
        precondition(PerfusionLocalization.resolvedLanguage(for: "system", preferredLanguages: ["fr-FR"]) == "fr")
        precondition(PerfusionLocalization.resolvedLanguage(for: "invalid", preferredLanguages: ["de-DE"]) == "de")
        for code in PerfusionLocalization.languages {
            preferences.setVolatileDomain([PerfusionLocalization.preferenceKey: code],
                                          forName: UserDefaults.argumentDomain)
            precondition(PerfusionLocalization.preference == code)
            precondition(PerfusionLocalization.language == code)
            precondition(PerfusionLocalization.resolvedLanguage(for: code, preferredLanguages: ["en"]) == code)
            precondition(!PerfusionLocalization.nativeName(for: code).isEmpty)
            let label = L("field.language")
            precondition(label != "field.language" && !label.isEmpty)
            precondition(L("help.language") != "help.language")
            precondition(L("help.ktrans") != "help.ktrans")
            precondition(!L("dimensions", 2, 10).contains("$@"))
        }
        preferences.setVolatileDomain([PerfusionLocalization.preferenceKey: "de"],
                                      forName: UserDefaults.argumentDomain)
        precondition(L("field.language") == "Sprache")
        preferences.setVolatileDomain([PerfusionLocalization.preferenceKey: "en"],
                                      forName: UserDefaults.argumentDomain)
        precondition(L("field.language") == "Language")
        print("LocalizationTests: ten languages, live switching and tooltips passed")
    }
}
