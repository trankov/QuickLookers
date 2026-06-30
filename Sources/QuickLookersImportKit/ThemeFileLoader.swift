import Foundation

public enum ThemeFileError: Error { case badPlist, badJSON }

/// Приводит файл темы (из расширения редактора или .vsix) к строгому VS Code-JSON,
/// пригодному для ThemeNormalizer и движка. .json/.jsonc — через JSONCParser;
/// .tmTheme/.plist — plist → { name, type, tokenColors:[...] } (массив settings TextMate
/// раскладывается в tokenColors; первый бесскоупный элемент несёт background/foreground).
public enum ThemeFileLoader {
    public static func loadStrictThemeJSON(data: Data, fileExtension: String, uiTheme: String) throws -> Data {
        let ext = fileExtension.lowercased()
        if ext == "tmtheme" || ext == "plist" {
            return try convertTmTheme(data, uiTheme: uiTheme)
        }
        // .json / .jsonc / прочее → терпимый разбор в строгий JSON.
        do { return try JSONCParser.toStrictJSON(data) }
        catch { throw ThemeFileError.badJSON }
    }

    private static func convertTmTheme(_ data: Data, uiTheme: String) throws -> Data {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else { throw ThemeFileError.badPlist }
        let name = dict["name"] as? String ?? "Imported Theme"
        let settings = dict["settings"] as? [[String: Any]] ?? []
        let type = (uiTheme == "vs-dark" || uiTheme == "hc-black") ? "dark" : "light"
        let theme: [String: Any] = ["name": name, "type": type, "tokenColors": settings]
        guard let out = try? JSONSerialization.data(withJSONObject: theme) else { throw ThemeFileError.badPlist }
        return out
    }
}
