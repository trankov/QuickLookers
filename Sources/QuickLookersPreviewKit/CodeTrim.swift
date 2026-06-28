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
