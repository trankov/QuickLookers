import Foundation

/// Чтение/запись настроек как файла settings.json. Запись атомарна.
public struct SettingsStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Возвращает настройки из файла; при отсутствии/порче/чужой схеме — умолчания.
    public func load() -> ManagerSettings {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(ManagerSettings.self, from: data),
            decoded.schemaVersion == ManagerSettings.currentSchemaVersion
        else { return .default }
        return decoded
    }

    /// Пишет настройки, увеличив settingsVersion. Возвращает сохранённое значение.
    @discardableResult
    public func save(_ settings: ManagerSettings) throws -> ManagerSettings {
        var next = settings
        next.settingsVersion += 1
        let data = try JSONEncoder().encode(next)
        try data.write(to: fileURL, options: .atomic) // temp-файл + переименование
        return next
    }
}

/// id темы с откатом на тёмную по умолчанию, если выбранного нет в каталоге.
public func resolvedThemeId(activeThemeId: String, availableThemeIds: Set<String>) -> String {
    availableThemeIds.contains(activeThemeId) ? activeThemeId : DefaultThemeIds.dark
}

/// Идентификатор общего контейнера App Group. Префикс — Team ID (5FVC5YT2B5),
/// а не «group.»: macOS сверяет его с подписью кода и пускает в контейнер без
/// провижн-профиля и без запроса «доступ к данным других приложений».
public let quickLookersAppGroupId = "5FVC5YT2B5.com.quicklookers"

/// URL общего контейнера App Group (nil, если entitlement не настроен).
public func quickLookersContainerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: quickLookersAppGroupId)
}
