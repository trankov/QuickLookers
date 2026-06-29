import Foundation

public enum ManifestError: Error { case badJSON, noContributions }

/// Разобранный package.json расширения VS Code (только нужные contributes.*).
public struct VsixManifest: Equatable {
    public struct Grammar: Equatable {
        public let language: String?            // nil = грамматика-инъекция (injectTo)
        public let path: String
        public let embeddedLanguageIds: [String]  // значения contributes.grammars[].embeddedLanguages
        public init(language: String?, path: String, embeddedLanguageIds: [String]) {
            self.language = language; self.path = path; self.embeddedLanguageIds = embeddedLanguageIds
        }
    }
    public struct Theme: Equatable {
        public let label: String; public let uiTheme: String; public let path: String
        public init(label: String, uiTheme: String, path: String) {
            self.label = label; self.uiTheme = uiTheme; self.path = path
        }
    }
    public let grammars: [Grammar]
    public let themes: [Theme]
    public let languageDisplayNames: [String: String]

    public init(grammars: [Grammar], themes: [Theme], languageDisplayNames: [String: String]) {
        self.grammars = grammars; self.themes = themes; self.languageDisplayNames = languageDisplayNames
    }

    public static func parse(packageJSON data: Data) throws -> VsixManifest {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contributes = root["contributes"] as? [String: Any]
        else {
            // Невалидный JSON — badJSON; валидный, но без contributes — noContributions.
            if (try? JSONSerialization.jsonObject(with: data)) == nil { throw ManifestError.badJSON }
            throw ManifestError.noContributions
        }

        let grammars: [Grammar] = (contributes["grammars"] as? [[String: Any]] ?? []).map { g in
            let embedded = (g["embeddedLanguages"] as? [String: String]).map { Array(Set($0.values)) } ?? []
            return Grammar(language: g["language"] as? String,
                           path: g["path"] as? String ?? "",
                           embeddedLanguageIds: embedded.sorted())
        }
        let themes: [Theme] = (contributes["themes"] as? [[String: Any]] ?? []).compactMap { t in
            guard let label = t["label"] as? String, let path = t["path"] as? String else { return nil }
            return Theme(label: label, uiTheme: t["uiTheme"] as? String ?? "vs-dark", path: path)
        }
        var names: [String: String] = [:]
        for l in (contributes["languages"] as? [[String: Any]] ?? []) {
            if let id = l["id"] as? String {
                names[id] = (l["aliases"] as? [String])?.first ?? id
            }
        }
        guard !grammars.isEmpty || !themes.isEmpty else { throw ManifestError.noContributions }
        return VsixManifest(grammars: grammars, themes: themes, languageDisplayNames: names)
    }
}
