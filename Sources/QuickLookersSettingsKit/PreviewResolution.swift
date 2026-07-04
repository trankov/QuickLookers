/// Итог разрешения показа для файла.
public enum PreviewResolution: Equatable {
    /// Красить подсветкой указанным языком.
    case highlight(languageId: String)
    /// Рисовать нейтральным моноширинным текстом (выключено/неизвестно).
    case neutral
}

/// Язык включён в библиотеке (Слой 1), если он не в множестве выключенных.
public func isLanguageEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    !settings.disabledLanguageIds.contains(id)
}

/// Как показывать файл по пробелу.
/// Порядок: (1) правила пользователя — по убыванию специфичности, первое включённое
/// совпадение решает; (2) датасет — сначала точное имя файла, затем расширение;
/// (3) иначе нейтраль. Язык, выключенный в Слое 1, форсит нейтраль на любом уровне.
public func resolvePreview(fileName: String, pathExtension: String,
                           associations: FileTypeAssociations,
                           settings: ManagerSettings) -> PreviewResolution {
    func resolved(_ languageId: String) -> PreviewResolution {
        isLanguageEnabled(languageId, settings: settings) ? .highlight(languageId: languageId) : .neutral
    }

    // 1) Правила пользователя. Компилируем включённые, берём самое специфичное совпадение.
    let matches: [(rule: PreviewRule, spec: Int)] = settings.previewRules.compactMap { rule in
        guard rule.isEnabled else { return nil }
        let m = GlobMatcher(rule.pattern)
        return m.matches(fileName: fileName) ? (rule, m.specificity) : nil
    }
    if let winner = matches.max(by: { $0.spec < $1.spec })?.rule {
        switch winner.action {
        case .neutral: return .neutral
        case .assign(let lang): return resolved(lang)
        }
    }

    // 2) Датасет: имя файла приоритетнее расширения.
    if let lang = associations.byFilename[fileName] { return resolved(lang) }
    let ext = pathExtension.lowercased()
    if !ext.isEmpty, let lang = associations.byExtension[ext] { return resolved(lang) }

    // 3) Дошло, но неизвестно → нейтраль.
    return .neutral
}
