import Foundation

/// Безопасен ли id для использования как имя файла `<id>.json` в библиотеке.
/// Только ASCII [A-Za-z0-9_-], длина 1…64. Отсекает '/', '\\', '.', '..', пробелы,
/// пустые и слишком длинные — защита от path traversal при недоверенном .vsix.
public func isSafeImportID(_ id: String) -> Bool {
    guard (1...64).contains(id.count) else { return false }
    return id.allSatisfy { ch in
        ch.isASCII && (ch.isLetter || ch.isNumber || ch == "-" || ch == "_")
    }
}
