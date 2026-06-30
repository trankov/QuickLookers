import Foundation

/// Режет код до первых `max` строк. `truncated` = true, если что-то отрезано.
/// Пустой ввод → ("", false). Разделитель строк — `\n`. Один финальный `\n`
/// (обычное завершение текстового файла) не считается отдельной лишней
/// строкой — иначе файл ровно из `max` строк с финальным переводом строки
/// ложно помечался бы как обрезанный.
public func trimToFirstLines(_ code: String, max: Int) -> (code: String, truncated: Bool) {
    var body = Substring(code)
    if body.hasSuffix("\n") { body.removeLast() }
    let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
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
    // UTF-8 символ — до 4 байт; отрезаем хвост срезом (без копии буфера),
    // пока префикс не декодируется.
    for drop in 1...3 where data.count - drop > 0 {
        if let s = String(data: data.prefix(data.count - drop), encoding: .utf8) { return s }
    }
    throw CocoaError(.fileReadInapplicableStringEncoding)
}
