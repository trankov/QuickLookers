import Foundation
import AppKit
import UniformTypeIdentifiers
import QuickLookersEngine
import QuickLookersImportKit
import QuickLookersSettingsKit

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
            return ImportOutcome(didChange: false, errorText: "Нет общего контейнера — импорт недоступен.")
        }
        do {
            let data = try Data(contentsOf: url)
            let importer = VsixImporter(bundledGrammarsDir: try QuickLookersEngineResources.grammarsDirectory())
            let result = try importer(vsixData: data)
            try ImportedLibrary(containerURL: container).write(result)
            if result.artifacts.isEmpty {
                // contributes были, но всё отсеяно (только инъекции/негодные id) — успехом не считаем.
                return ImportOutcome(didChange: false,
                                     errorText: "В файле не нашлось тем или грамматик для импорта.")
            }
            // Успех виден по списку; число пропусков (служебные инъекции) не показываем.
            return ImportOutcome(didChange: true, errorText: nil)
        } catch let e as ImportError {
            return ImportOutcome(didChange: false, errorText: Self.message(for: e))
        } catch {
            return ImportOutcome(didChange: false, errorText: "Не удалось прочитать файл.")
        }
    }

    private static func message(for error: ImportError) -> String {
        switch error {
        case .notArchive:      return "Это не похоже на файл расширения .vsix."
        case .tooLarge:        return "Файл слишком большой или повреждён."
        case .noManifest:      return "В расширении не найден package.json."
        case .noContributions: return "В расширении нет тем и грамматик для импорта."
        }
    }

    func remove(kind: ImportArtifact.Kind, id: String) {
        guard let container = quickLookersContainerURL() else { return }
        try? ImportedLibrary(containerURL: container).remove(kind: kind, id: id)
    }
}
