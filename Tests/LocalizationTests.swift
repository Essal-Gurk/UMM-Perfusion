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
            for key in ["model.standard", "model.extended", "model.deconvolution",
                        "signal.relative", "signal.absolute", "signal.dsc"] {
                precondition(L(key) == PerfusionLocalization.text(key, language: code))
                precondition(L(key) != key)
            }
            for language in PerfusionLocalization.languages {
                precondition(L("language." + language) != "language." + language)
            }
        }
        preferences.setVolatileDomain([PerfusionLocalization.preferenceKey: "de"],
                                      forName: UserDefaults.argumentDomain)
        precondition(L("field.language") == "Sprache")
        let message = T("error.stage", T("stage.import", T("map.flow")),
                        T("error.number", T("field.hct")))
        let german = message.rendered()
        precondition(german.contains("Plasmafluss") && german.contains("Hämatokrit"))
        preferences.setVolatileDomain([PerfusionLocalization.preferenceKey: "en"],
                                      forName: UserDefaults.argumentDomain)
        precondition(L("field.language") == "Language")
        precondition(L("model.extended") == "Extended Tofts")
        precondition(L("signal.relative") == "T1-DCE · relative enhancement")
        precondition(message.rendered().contains("Plasma flow"))
        precondition(message.rendered().contains("Hematocrit"))
        precondition(!message.rendered().contains("Hämatokrit"))
        precondition(!message.rendered().contains("Plasmafluss"))
        precondition(T("stage.read", 2, 10).rendered() == L("stage.read", 2, 10))
        print("LocalizationTests: ten languages, live switching and tooltips passed")
    }
}
