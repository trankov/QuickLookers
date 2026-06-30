import Foundation
import QuickLookersImportKit

/// Запись/удаление импортированных грамматик и тем в контейнере App Group и
/// поддержка сайдкара catalog-imported.json (формат FileCatalogSource.Sidecar).
public struct ImportedLibrary {
    private let containerURL: URL
    public init(containerURL: URL) { self.containerURL = containerURL }

    private var libraryDir: URL { containerURL.appendingPathComponent("library") }
    public var grammarsDir: URL { libraryDir.appendingPathComponent("grammars") }
    public var themesDir: URL { libraryDir.appendingPathComponent("themes") }
    public var sidecarURL: URL { libraryDir.appendingPathComponent("catalog-imported.json") }

    public func sidecarURLsForCatalog() -> [URL] {
        FileManager.default.fileExists(atPath: sidecarURL.path) ? [sidecarURL] : []
    }

    /// id всех импортированных языков и тем (для пометки «импортированное» в UI).
    public func importedIds() -> Set<String> {
        let s = loadSidecar()
        return Set(s.languages.keys).union(s.themes.keys)
    }

    /// Пишет файлы артефактов и доливает их записи в сайдкар (слияние по id).
    public func write(_ result: ImportResult) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: grammarsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: themesDir, withIntermediateDirectories: true)

        var sidecar = loadSidecar()
        for a in result.artifacts {
            guard isSafeImportID(a.id) else { continue }   // защита FS-границы (импортёр уже фильтрует)
            switch a.kind {
            case .grammar:
                try a.json.write(to: grammarsDir.appendingPathComponent("\(a.id).json"), options: .atomic)
                sidecar.languages[a.id] = ["id": a.id, "displayName": a.displayName]
            case .theme:
                try a.json.write(to: themesDir.appendingPathComponent("\(a.id).json"), options: .atomic)
                sidecar.themes[a.id] = ["id": a.id, "displayName": a.displayName, "isDark": a.isDark]
            }
        }
        try saveSidecar(sidecar)
    }

    public func remove(kind: ImportArtifact.Kind, id: String) throws {
        guard isSafeImportID(id) else { return }
        let fm = FileManager.default
        var sidecar = loadSidecar()
        switch kind {
        case .grammar:
            try? fm.removeItem(at: grammarsDir.appendingPathComponent("\(id).json"))
            sidecar.languages[id] = nil
        case .theme:
            try? fm.removeItem(at: themesDir.appendingPathComponent("\(id).json"))
            sidecar.themes[id] = nil
        }
        try saveSidecar(sidecar)
    }

    // Сайдкар как словари по id (для слияния и удаления), сериализуем в формат FileCatalogSource.
    private struct Sidecar { var languages: [String: [String: Any]] = [:]; var themes: [String: [String: Any]] = [:] }

    private func loadSidecar() -> Sidecar {
        guard let data = try? Data(contentsOf: sidecarURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return Sidecar() }
        var s = Sidecar()
        for l in (obj["languages"] as? [[String: Any]] ?? []) { if let id = l["id"] as? String { s.languages[id] = l } }
        for t in (obj["themes"] as? [[String: Any]] ?? []) { if let id = t["id"] as? String { s.themes[id] = t } }
        return s
    }

    private func saveSidecar(_ s: Sidecar) throws {
        let obj: [String: Any] = [
            "languages": s.languages.sorted { $0.key < $1.key }.map(\.value),
            "themes":    s.themes.sorted    { $0.key < $1.key }.map(\.value),
        ]
        // libraryDir может ещё не существовать (например remove() вызван до
        // первого write()) — атомарная запись требует существующей директории.
        try FileManager.default.createDirectory(at: libraryDir, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: obj).write(to: sidecarURL, options: .atomic)
    }
}
