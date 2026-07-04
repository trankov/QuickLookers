import Foundation
import AppKit
import UniformTypeIdentifiers
import QuickLookersEngine
import QuickLookersImportKit
import QuickLookersSettingsKit
import QuickLookersEditorKit

/// Результат попытки импорта для обратной связи во вкладке.
struct ImportOutcome {
    /// Что-то импортировано → перечитать каталог и очистить строку ошибки.
    let didChange: Bool
    /// Текст ошибки или «ничего не нашлось»; nil при успехе.
    let errorText: String?
}

/// Логика импорта в приложении: пикер .vsix → ImportKit → запись в контейнер.
/// Состояния не держит — обратная связь живёт в @State вкладки.
@MainActor
final class ImportModel: ObservableObject {
    /// Открывает пикер .vsix и импортирует. nil — пользователь отменил выбор.
    func runImport() -> ImportOutcome? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "vsix") ?? .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return importFile(url)
    }

    func importFile(_ url: URL) -> ImportOutcome {
        guard let container = quickLookersContainerURL() else {
            return ImportOutcome(didChange: false, errorText: String(localized: "No shared container — import unavailable."))
        }
        do {
            let data = try Data(contentsOf: url)
            let importer = VsixImporter(bundledGrammarsDir: try QuickLookersEngineResources.grammarsDirectory())
            let result = try importer(vsixData: data)
            try ImportedLibrary(containerURL: container).write(result)
            if result.artifacts.isEmpty {
                // contributes были, но всё отсеяно (только инъекции/негодные id) — успехом не считаем.
                return ImportOutcome(didChange: false,
                                     errorText: String(localized: "No themes or grammars to import were found in the file."))
            }
            // Успех виден по списку; число пропусков (служебные инъекции) не показываем.
            return ImportOutcome(didChange: true, errorText: nil)
        } catch let e as ImportError {
            return ImportOutcome(didChange: false, errorText: Self.message(for: e))
        } catch {
            return ImportOutcome(didChange: false, errorText: String(localized: "Couldn't read the file."))
        }
    }

    /// internal (не private) — чтобы маппинг ошибок был напрямую покрыт unit-тестом
    /// без необходимости гонять весь importFile() через реальный контейнер App Group.
    static func message(for error: ImportError) -> String {
        switch error {
        case .notArchive:      return String(localized: "This doesn't look like a .vsix extension file.")
        case .tooLarge:        return String(localized: "The file is too large or corrupted.")
        case .noManifest:      return String(localized: "package.json wasn't found in the extension.")
        case .noContributions: return String(localized: "The extension has no themes or grammars to import.")
        }
    }

    func remove(kind: ImportArtifact.Kind, id: String) {
        guard let container = quickLookersContainerURL() else { return }
        try? ImportedLibrary(containerURL: container).remove(kind: kind, id: id)
    }

    // MARK: - Импорт из установленного редактора

    /// Что применить после импорта из редактора.
    struct EditorImportOutcome { let themeId: String?; let font: FontSettings; let message: String? }

    /// Список установленных VS Code-подобных редакторов (грант на /Applications — лениво).
    func scanEditors(_ store: BookmarkStore) -> [DetectedEditor] {
        store.withAccess(.applications) { appsURL in
            EditorScanner.scan(applicationsDir: appsURL)
        } ?? []
    }

    /// Читает из редактора активную тему и шрифт, на .custom — импортирует тему,
    /// возвращает что применить. Доступ к ~ берётся внутри (грант при первом разе).
    func importFromEditor(_ editor: DetectedEditor, store: BookmarkStore,
                          catalog: ThemeCatalogLookup) -> EditorImportOutcome {
        let emptyFont = FontSettings(family: nil, size: nil)
        guard let container = quickLookersContainerURL() else {
            return EditorImportOutcome(themeId: nil, font: emptyFont,
                                       message: String(localized: "No shared container — import unavailable."))
        }
        return store.withAccess(.home) { home in
            let appSupport = home.appendingPathComponent("Library/Application Support")
            let prefs = EditorSettingsReader.read(editor: editor, appSupportDir: appSupport)
            // Размер из редактора зажимаем в допустимый диапазон сразу на входе в модель.
            let font = FontSettings(family: prefs.fontFamily, size: FontSettings.clampSize(prefs.fontSize))
            guard let label = prefs.colorThemeLabel else {
                return EditorImportOutcome(themeId: nil, font: font,
                                           message: String(localized: "The editor has no theme set — applied font only."))
            }
            let extDir = home.appendingPathComponent("\(editor.dataFolderName)/extensions")
            switch EditorThemeResolver.resolve(label: label, catalog: catalog, extensionsDir: extDir) {
            case .bundled(let id):
                return EditorImportOutcome(themeId: id, font: font, message: nil)
            case .custom(let lbl, let uiTheme, let fileURL):
                guard let raw = try? Data(contentsOf: fileURL),
                      let strict = try? ThemeFileLoader.loadStrictThemeJSON(
                          data: raw, fileExtension: fileURL.pathExtension, uiTheme: uiTheme) else {
                    return EditorImportOutcome(themeId: nil, font: font,
                                               message: String(localized: "Theme '\(lbl)' couldn't be read — applied font only."))
                }
                let lib = ImportedLibrary(containerURL: container)
                let existing = Set(lib.importedIds())
                let n = ThemeNormalizer.normalize(label: lbl, uiTheme: uiTheme,
                                                  themeJSON: strict, existingSlugs: existing)
                let artifact = ImportArtifact(kind: .theme, id: n.id, displayName: n.displayName,
                                              isDark: n.isDark, json: n.json)
                try? lib.write(ImportResult(artifacts: [artifact], skips: []))
                return EditorImportOutcome(themeId: n.id, font: font, message: nil)
            case .notFound:
                return EditorImportOutcome(themeId: nil, font: font,
                                           message: String(localized: "Theme '\(label)' wasn't found — applied font only."))
            }
        } ?? EditorImportOutcome(themeId: nil, font: emptyFont,
                                 message: String(localized: "Home folder access wasn't granted."))
    }
}
