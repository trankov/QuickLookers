import Foundation

public enum JSONCError: Error { case invalid }

/// Разбор JSONC (JSON с комментариями и висячими запятыми), как у settings.json VS Code.
/// Удаляет // и /* */ комментарии и висячие запятые С УЧЁТОМ строковых литералов;
/// экранирует сырые управляющие символы внутри строк, чтобы JSONSerialization не падал.
public enum JSONCParser {
    public static func object(from data: Data) throws -> Any {
        let strict = try toStrictJSON(data)
        guard let obj = try? JSONSerialization.jsonObject(with: strict, options: [.fragmentsAllowed]) else {
            throw JSONCError.invalid
        }
        return obj
    }

    public static func toStrictJSON(_ data: Data) throws -> Data {
        guard let s = String(data: data, encoding: .utf8) else { throw JSONCError.invalid }
        var out = String(); out.reserveCapacity(s.count)
        var inString = false
        var escape = false
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if inString {
                if escape {
                    out.append(c); escape = false
                } else if c == "\\" {
                    out.append(c); escape = true
                } else if c == "\"" {
                    out.append(c); inString = false
                } else if let scalar = c.unicodeScalars.first, scalar.value < 0x20 {
                    // Сырой управляющий символ внутри строки → экранируем.
                    switch c {
                    case "\n": out += "\\n"
                    case "\t": out += "\\t"
                    case "\r": out += "\\r"
                    default: out += String(format: "\\u%04x", scalar.value)
                    }
                } else {
                    out.append(c)
                }
                i = s.index(after: i); continue
            }
            // Вне строки.
            if c == "\"" { inString = true; out.append(c); i = s.index(after: i); continue }
            let next = s.index(after: i)
            if c == "/" && next < s.endIndex && s[next] == "/" {
                // Строчный комментарий до конца строки.
                i = next
                while i < s.endIndex && s[i] != "\n" { i = s.index(after: i) }
                continue
            }
            if c == "/" && next < s.endIndex && s[next] == "*" {
                // Блочный комментарий.
                i = s.index(after: next)
                while i < s.endIndex {
                    if s[i] == "*", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "/" {
                        i = s.index(i, offsetBy: 2); break
                    }
                    i = s.index(after: i)
                }
                continue
            }
            out.append(c)
            i = next
        }
        // Висячие запятые: , перед } или ] (с любыми пробелами между).
        let stripped = stripTrailingCommas(out)
        return Data(stripped.utf8)
    }

    private static func stripTrailingCommas(_ s: String) -> String {
        var out = String(); out.reserveCapacity(s.count)
        var inString = false, escape = false
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inString {
                out.append(c)
                if escape { escape = false }
                else if c == "\\" { escape = true }
                else if c == "\"" { inString = false }
                i += 1; continue
            }
            if c == "\"" { inString = true; out.append(c); i += 1; continue }
            if c == "," {
                // Заглянуть вперёд: если следующий значимый символ — } или ], запятую выбросить.
                var j = i + 1
                while j < chars.count, chars[j].isWhitespace { j += 1 }
                if j < chars.count, chars[j] == "}" || chars[j] == "]" { i += 1; continue }
            }
            out.append(c); i += 1
        }
        return out
    }
}
