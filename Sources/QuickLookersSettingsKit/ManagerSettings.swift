/// Дефолтные id встроенных тем VS Code.
public enum DefaultThemeIds {
    public static let light = "light-plus"
    public static let dark = "dark-plus"
}

/// Шрифт превью. nil = умолчание движка (текущий моноширинный стек / размер).
public struct FontSettings: Codable, Equatable {
    public var family: String?
    public var size: Double?
    public init(family: String?, size: Double?) { self.family = family; self.size = size }
}

/// Настройки менеджера. Модель opt-out: храним выключенное, пусто = всё включено.
public struct ManagerSettings: Codable, Equatable {
    public var schemaVersion: Int
    public var settingsVersion: Int
    public var disabledLanguageIds: Set<String>
    public var activeThemeId: String
    public var font: FontSettings
    public var previewDisabledLanguageIds: Set<String>

    public init(schemaVersion: Int, settingsVersion: Int, disabledLanguageIds: Set<String>,
                activeThemeId: String, font: FontSettings, previewDisabledLanguageIds: Set<String>) {
        self.schemaVersion = schemaVersion
        self.settingsVersion = settingsVersion
        self.disabledLanguageIds = disabledLanguageIds
        self.activeThemeId = activeThemeId
        self.font = font
        self.previewDisabledLanguageIds = previewDisabledLanguageIds
    }

    public static let currentSchemaVersion = 1

    public static let `default` = ManagerSettings(
        schemaVersion: currentSchemaVersion,
        settingsVersion: 0,
        disabledLanguageIds: [],
        activeThemeId: DefaultThemeIds.dark,
        font: FontSettings(family: nil, size: nil),
        previewDisabledLanguageIds: []
    )
}
