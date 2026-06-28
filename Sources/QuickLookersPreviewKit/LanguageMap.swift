/// Соответствие «расширение файла → id грамматики Shiki».
/// Срез фазы 2: только языки, на которые есть грамматики в пакете.
private let extensionToLanguage: [String: String] = [
    "swift": "swift",
    "json": "json",
    "js": "javascript",
]

/// id грамматики для расширения файла или nil, если язык не поддержан.
public func languageId(forPathExtension ext: String) -> String? {
    extensionToLanguage[ext.lowercased()]
}
