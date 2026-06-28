/// Один объявленный тип: UTI в Info.plist, расширение файла, целевой язык.
public struct DeclaredType: Equatable {
    public let uti: String
    public let pathExtension: String
    public let languageId: String

    public init(uti: String, pathExtension: String, languageId: String) {
        self.uti = uti
        self.pathExtension = pathExtension
        self.languageId = languageId
    }
}

/// Граница Слоя 2: что объявлено в QLSupportedContentTypes расширения.
/// В этом срезе статично; позже — из конфигурации.
public enum DeclaredTypes {
    public static let all: [DeclaredType] = [
        DeclaredType(uti: "public.swift-source", pathExtension: "swift", languageId: "swift"),
        DeclaredType(uti: "public.json", pathExtension: "json", languageId: "json"),
        DeclaredType(uti: "com.netscape.javascript-source", pathExtension: "js", languageId: "javascript"),
    ]

    /// Язык для расширения файла среди объявленных типов (или nil).
    public static func languageId(forPathExtension ext: String) -> String? {
        let lower = ext.lowercased()
        return all.first { $0.pathExtension == lower }?.languageId
    }
}

/// Язык включён в библиотеке (Слой 1), если он не в множестве выключенных.
public func isLanguageEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    !settings.disabledLanguageIds.contains(id)
}

/// Язык показывается в Finder, если он включён и не убран из просмотра.
public func isPreviewEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    isLanguageEnabled(id, settings: settings)
        && !settings.previewDisabledLanguageIds.contains(id)
}

/// Язык, которым красить файл по пробелу, или nil → отдать системе.
public func previewLanguageId(forPathExtension ext: String, settings: ManagerSettings) -> String? {
    guard let lang = DeclaredTypes.languageId(forPathExtension: ext) else { return nil }
    guard isPreviewEnabled(lang, settings: settings) else { return nil }
    return lang
}
