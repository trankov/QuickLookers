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

/// Кандидат темы с откатом, если выбранного id нет в каталоге.
public func resolvedThemeId(_ theme: ThemeSelection,
                            availableThemeIds: Set<String>,
                            appearanceIsDark: Bool) -> String {
    let candidate = theme.resolvedThemeId(appearanceIsDark: appearanceIsDark)
    if availableThemeIds.contains(candidate) { return candidate }
    return appearanceIsDark ? DefaultThemeIds.dark : DefaultThemeIds.light
}

/// Идентификатор общего контейнера App Group.
public let quickLookersAppGroupId = "group.com.quicklookers"

/// URL общего контейнера App Group (nil, если entitlement не настроен).
public func quickLookersContainerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: quickLookersAppGroupId)
}
