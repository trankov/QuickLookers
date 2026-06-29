import Foundation

public struct NormalizedTheme: Equatable {
    public let id: String; public let displayName: String; public let isDark: Bool; public let json: Data
    public init(id: String, displayName: String, isDark: Bool, json: Data) {
        self.id = id; self.displayName = displayName; self.isDark = isDark; self.json = json
    }
}

public enum ThemeNormalizer {
    /// id из label: нижний регистр, недопустимые символы → '-', схлопывание и обрезка дефисов.
    public static func slug(_ label: String) -> String {
        let lowered = label.lowercased()
        var out = ""
        for ch in lowered {
            if ch.isLetter || ch.isNumber { out.append(ch) }
            else if !out.hasSuffix("-") { out.append("-") }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    public static func isDark(uiTheme: String) -> Bool {
        uiTheme == "vs-dark" || uiTheme == "hc-black"
    }

    /// Уникализирует слаг относительно existingSlugs суффиксом -2, -3, …
    public static func normalize(label: String, uiTheme: String, themeJSON: Data,
                                 existingSlugs: Set<String>) -> NormalizedTheme {
        let base = slug(label)
        var id = base
        var n = 2
        while existingSlugs.contains(id) { id = "\(base)-\(n)"; n += 1 }
        return NormalizedTheme(id: id, displayName: label, isDark: isDark(uiTheme: uiTheme), json: themeJSON)
    }
}
