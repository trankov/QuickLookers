import Foundation
import QuickLookersImportKit

public struct EditorPreferences: Equatable {
    public let colorThemeLabel: String?
    public let fontFamily: String?
    public let fontSize: Double?
    public init(colorThemeLabel: String?, fontFamily: String?, fontSize: Double?) {
        self.colorThemeLabel = colorThemeLabel; self.fontFamily = fontFamily; self.fontSize = fontSize
    }
}

/// Читает <appSupportDir>/<nameShort|nameLong>/User/settings.json (JSONC) и
/// достаёт активную тему и шрифт. Любая ошибка/отсутствие → nil-поля.
public enum EditorSettingsReader {
    public static func read(editor: DetectedEditor, appSupportDir: URL) -> EditorPreferences {
        let fm = FileManager.default
        let candidates = [editor.nameShort, editor.nameLong]
        let url = candidates.lazy
            .map { appSupportDir.appendingPathComponent("\($0)/User/settings.json") }
            .first { fm.fileExists(atPath: $0.path) }
        guard let url,
              let data = try? Data(contentsOf: url),
              let obj = try? JSONCParser.object(from: data) as? [String: Any]
        else { return EditorPreferences(colorThemeLabel: nil, fontFamily: nil, fontSize: nil) }
        // JSONSerialization отдаёт числа как NSNumber → as? Double ловит и целые (13 → 13.0).
        return EditorPreferences(
            colorThemeLabel: obj["workbench.colorTheme"] as? String,
            fontFamily: obj["editor.fontFamily"] as? String,
            fontSize: obj["editor.fontSize"] as? Double)
    }
}
