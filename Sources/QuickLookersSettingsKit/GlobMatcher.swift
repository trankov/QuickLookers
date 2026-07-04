import Foundation

/// Сопоставление полного имени файла с glob-шаблоном. Три подстановочных знака:
///   `*` — ноль или больше любых символов;
///   `?` — ровно один любой символ;
///   `~` — ноль или один любой символ (необязательный, для семей `.htm/.html`, `.yml/.yaml`).
/// Экранирование: `/` перед символом делает его литералом (`/~` → обычная тильда,
/// `/*` → звёздочка). `/` выбран экранирующим — в имени файла он не встречается.
/// Классов `[...]` и регулярок нет. Сопоставление регистронезависимо.
public struct GlobMatcher: Equatable {
    public let pattern: String
    private let tokens: [Token]

    enum Token: Equatable { case literal(Character); case star; case one; case optional }

    public init(_ pattern: String) {
        self.pattern = pattern
        self.tokens = Self.parse(pattern)
    }

    /// Разбор шаблона в токены с учётом экранирования `/`.
    private static func parse(_ pattern: String) -> [Token] {
        let chars = Array(pattern)
        var out: [Token] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "/", i + 1 < chars.count {   // экранирование: /X → литерал X
                out.append(.literal(chars[i + 1])); i += 2; continue
            }
            switch c {
            case "*": out.append(.star)
            case "?": out.append(.one)
            case "~": out.append(.optional)
            default:  out.append(.literal(c))
            }
            i += 1
        }
        return out
    }

    private var wildcardCount: Int {
        tokens.reduce(0) { if case .literal = $1 { return $0 } else { return $0 + 1 } }
    }
    private var hasWildcard: Bool { wildcardCount > 0 }
    private var literalCount: Int { tokens.count - wildcardCount }

    public func matches(fileName: String) -> Bool {
        Self.match(tokens, 0, Array(fileName.lowercased()), 0)
    }

    /// Чем больше литералов и меньше wildcard — тем специфичнее. Точное имя
    /// (без wildcard) всегда выше любого glob.
    public var specificity: Int { hasWildcard ? literalCount : 1000 + literalCount }

    /// «*.ext» одним сегментом (без точки/wildcard в остатке) → «ext» (lower). Иначе nil.
    public var fastExtension: String? {
        guard tokens.count >= 3, tokens[0] == .star, tokens[1] == .literal(".") else { return nil }
        var ext = ""
        for tk in tokens.dropFirst(2) {
            guard case .literal(let c) = tk, c != "." else { return nil }
            ext.append(c)
        }
        return ext.isEmpty ? nil : ext.lowercased()
    }

    /// Шаблон без wildcard — это точное имя файла (с раскрытыми экранированиями).
    public var exactFilename: String? {
        guard !hasWildcard else { return nil }
        return String(tokens.compactMap { if case .literal(let c) = $0 { return c } else { return nil } })
    }

    /// Расширение, по которому можно проверить перехват; nil если неопределимо.
    public var probeExtension: String? {
        if let f = fastExtension { return f }
        if let name = exactFilename, name.contains(".") {
            return name.split(separator: ".").last.map { $0.lowercased() }
        }
        return nil
    }

    /// Рекурсивный матчер: `*` (ноль+), `?` (ровно один), `~` (ноль или один).
    private static func match(_ t: [Token], _ ti: Int, _ s: [Character], _ si: Int) -> Bool {
        if ti == t.count { return si == s.count }
        switch t[ti] {
        case .literal(let c):
            return si < s.count && String(c).lowercased() == String(s[si]) && match(t, ti + 1, s, si + 1)
        case .one:
            return si < s.count && match(t, ti + 1, s, si + 1)
        case .optional:
            return match(t, ti + 1, s, si) || (si < s.count && match(t, ti + 1, s, si + 1))
        case .star:
            return match(t, ti + 1, s, si) || (si < s.count && match(t, ti, s, si + 1))
        }
    }
}
