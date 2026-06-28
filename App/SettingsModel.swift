import Foundation
import SwiftUI
import QuickLookersEngine
import QuickLookersSettingsKit

/// Состояние окна: настройки в памяти + каталог доступного.
/// Любое изменение сразу пишется в settings.json (с ростом settingsVersion).
@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: ManagerSettings
    @Published private(set) var warning: String?
    let catalog: Catalog

    private let store: SettingsStore?

    init() {
        // Каталог из ресурсов движка.
        let loadedCatalog: Catalog
        do {
            let source = FileCatalogSource(
                grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
                themesDirectory: try QuickLookersEngineResources.themesDirectory())
            loadedCatalog = try source.loadCatalog()
        } catch {
            loadedCatalog = Catalog(languages: [], themes: [])
        }
        self.catalog = loadedCatalog

        // Хранилище — в общем контейнере. Нет контейнера → окно работает,
        // но предупреждаем: подпись/entitlement не настроены.
        if let container = quickLookersContainerURL() {
            let store = SettingsStore(fileURL: container.appendingPathComponent("settings.json"))
            self.store = store
            self.settings = store.load()
            self.warning = nil
        } else {
            self.store = nil
            self.settings = .default
            self.warning = "Контейнер App Group недоступен — изменения не сохраняются. Проверь подпись и entitlement."
        }
    }

    /// Изменить настройки и сразу сохранить.
    func update(_ mutate: (inout ManagerSettings) -> Void) {
        mutate(&settings)
        guard let store else { return }
        if let saved = try? store.save(settings) {
            settings = saved
        }
    }

    // Удобные производные для вкладок.
    func isLanguageOn(_ id: String) -> Bool { isLanguageEnabled(id, settings: settings) }
    func isPreviewOn(_ id: String) -> Bool { isPreviewEnabled(id, settings: settings) }
}
