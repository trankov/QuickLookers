import CryptoKit
import Foundation

public struct NormalizedTheme: Equatable {
    public let id: String; public let displayName: String; public let isDark: Bool; public let json: Data
    public init(id: String, displayName: String, isDark: Bool, json: Data) {
        self.id = id; self.displayName = displayName; self.isDark = isDark; self.json = json
    }
}

public enum ThemeNormalizer {
    /// id из label: нижний регистр, только ASCII-буквы/цифры, остальное → '-', схлопывание и обрезка дефисов.
    public static func slug(_ label: String) -> String {
        let lowered = label.lowercased()
        var out = ""
        for ch in lowered {
            if ch.isASCII && (ch.isLetter || ch.isNumber) { out.append(ch) }
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
        // Название целиком из не-ASCII/пунктуации → слаг пуст. Даём стабильный
        // ASCII-id из хэша названия, чтобы тема импортировалась, а не пропадала.
        let safeBase = base.isEmpty ? "theme-" + Self.shortHash(label) : base
        var id = safeBase
        var n = 2
        while existingSlugs.contains(id) { id = "\(safeBase)-\(n)"; n += 1 }
        return NormalizedTheme(id: id, displayName: label, isDark: isDark(uiTheme: uiTheme), json: themeJSON)
    }

    /// Короткий стабильный ASCII-хэш строки (8 hex) для запасного id.
    private static func shortHash(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}
