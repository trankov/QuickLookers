import Foundation
import AppKit
import UniformTypeIdentifiers
import QuickLookersEngine
import QuickLookersImportKit
import QuickLookersSettingsKit

/// Логика импорта в приложении: пикер .vsix → ImportKit → запись в контейнер → сводка.
@MainActor
final class ImportModel: ObservableObject {
    @Published var summary: String?

    /// Открывает .vsix, импортирует, пишет в контейнер. Возвращает true при успехе.
    func runImport() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "vsix") ?? .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return importFile(url)
    }

    func importFile(_ url: URL) -> Bool {
        guard let container = quickLookersContainerURL() else {
            summary = "Нет общего контейнера — импорт недоступен."; return false
        }
        do {
            let data = try Data(contentsOf: url)
            let importer = VsixImporter(bundledGrammarsDir: try QuickLookersEngineResources.grammarsDirectory())
            let result = try importer(vsixData: data)
            try ImportedLibrary(containerURL: container).write(result)
            let n = result.artifacts.count, m = result.skips.count
            summary = m == 0 ? "Импортировано: \(n)." : "Импортировано: \(n), пропущено: \(m)."
            return true
        } catch let e as ImportError {
            summary = Self.message(for: e)
            return false
        } catch {
            summary = "Не удалось прочитать файл."
            return false
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
