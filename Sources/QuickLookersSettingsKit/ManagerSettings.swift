import Foundation

/// Дефолтные id встроенных тем VS Code.
public enum DefaultThemeIds {
    public static let light = "light-plus"
    public static let dark = "dark-plus"
}

/// Выбор темы: «следовать за системой» (светлая+тёмная) либо фиксированная.
public struct ThemeSelection: Codable, Equatable {
    public var followSystem: Bool
    public var lightThemeId: String
    public var darkThemeId: String
    public var fixedThemeId: String

    public init(followSystem: Bool, lightThemeId: String, darkThemeId: String, fixedThemeId: String) {
        self.followSystem = followSystem
        self.lightThemeId = lightThemeId
        self.darkThemeId = darkThemeId
        self.fixedThemeId = fixedThemeId
    }

    /// Кандидат темы по текущему оформлению (без проверки наличия в каталоге).
    public func resolvedThemeId(appearanceIsDark: Bool) -> String {
        guard followSystem else { return fixedThemeId }
        return appearanceIsDark ? darkThemeId : lightThemeId
    }
}

/// Настройки менеджера. Модель opt-out: храним выключенное, пусто = всё включено.
public struct ManagerSettings: Codable, Equatable {
    public var schemaVersion: Int
    public var settingsVersion: Int
    public var disabledLanguageIds: Set<String>
    public var theme: ThemeSelection
    public var previewDisabledLanguageIds: Set<String>

    public init(schemaVersion: Int, settingsVersion: Int, disabledLanguageIds: Set<String>,
                theme: ThemeSelection, previewDisabledLanguageIds: Set<String>) {
        self.schemaVersion = schemaVersion
        self.settingsVersion = settingsVersion
        self.disabledLanguageIds = disabledLanguageIds
        self.theme = theme
        self.previewDisabledLanguageIds = previewDisabledLanguageIds
    }

    public static let currentSchemaVersion = 1

    public static let `default` = ManagerSettings(
        schemaVersion: currentSchemaVersion,
        settingsVersion: 0,
        disabledLanguageIds: [],
        theme: ThemeSelection(followSystem: true,
                              lightThemeId: DefaultThemeIds.light,
                              darkThemeId: DefaultThemeIds.dark,
                              fixedThemeId: DefaultThemeIds.dark),
        previewDisabledLanguageIds: []
    )
}
