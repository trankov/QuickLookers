import Foundation

/// Режет код до первых `max` строк. `truncated` = true, если что-то отрезано.
/// Пустой ввод → ("", false). Разделитель строк — `\n`.
public func trimToFirstLines(_ code: String, max: Int) -> (code: String, truncated: Bool) {
    let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
    if lines.count <= max {
        return (code, false)
    }
    let kept = lines.prefix(max).joined(separator: "\n")
    return (kept, true)
}

/// Читает не более `maxBytes` префикса файла как UTF-8. Если граница попала на
/// середину многобайтового символа — отбрасывает неполный хвост (до 3 байт).
/// Пустой файл возвращает пустую строку; непустые нечитаемые данные бросают ошибку.
public func readBoundedPrefix(of url: URL, maxBytes: Int) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: maxBytes) ?? Data()
    if let s = String(data: data, encoding: .utf8) { return s }
    // UTF-8 символ — до 4 байт; отрезаем хвост по байту, пока не декодируется.
    var trimmed = data
    for _ in 0..<3 {
        guard !trimmed.isEmpty else { break }
        trimmed.removeLast()
        if let s = String(data: trimmed, encoding: .utf8) { return s }
    }
    throw CocoaError(.fileReadInapplicableStringEncoding)
}
