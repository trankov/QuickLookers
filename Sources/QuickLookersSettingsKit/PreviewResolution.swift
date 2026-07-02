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

/// Как показывать файл по пробелу. Порядок: правило по имени файла (приоритетнее),
/// затем по расширению; пользовательские правки перекрывают датасет.
/// Всё, что дошло до расширения, но выключено/неизвестно → нейтральный текст
/// (не бросок): бросок оставлен только для нечитаемого файла на стороне расширения.
public func resolvePreview(fileName: String, pathExtension: String,
                           associations: FileTypeAssociations,
                           settings: ManagerSettings) -> PreviewResolution {
    func resolution(languageId: String, isDisabledForPreview: Bool) -> PreviewResolution {
        guard !isDisabledForPreview, isLanguageEnabled(languageId, settings: settings) else { return .neutral }
        return .highlight(languageId: languageId)
    }
    // 1) правило по имени файла (Dockerfile, CMakeLists.txt …)
    if let lang = settings.filenameOverrides[fileName] ?? associations.byFilename[fileName] {
        return resolution(languageId: lang, isDisabledForPreview: settings.disabledFilenames.contains(fileName))
    }
    // 2) правило по расширению
    let ext = pathExtension.lowercased()
    if !ext.isEmpty, let lang = settings.extensionOverrides[ext] ?? associations.byExtension[ext] {
        return resolution(languageId: lang, isDisabledForPreview: settings.disabledExtensions.contains(ext))
    }
    // 3) дошло (напр. по public.plain-text), но неизвестно → нейтральный текст
    return .neutral
}
