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

    /// Единый допустимый диапазон размера — для контролов UI и зажима импортируемых значений.
    public static let sizeRange: ClosedRange<Double> = 6...48

    /// Зажимает размер в допустимый диапазон (nil остаётся nil).
    public static func clampSize(_ size: Double?) -> Double? {
        size.map { min(max($0, sizeRange.lowerBound), sizeRange.upperBound) }
    }
}

/// Настройки менеджера. Модель opt-out: храним выключенное/переопределённое,
/// пусто = поведение по умолчанию (из сгенерированного датасета).
public struct ManagerSettings: Codable, Equatable {
    public var schemaVersion: Int
    public var settingsVersion: Int
    public var disabledLanguageIds: Set<String>          // Слой 1: язык выключен в библиотеке
    public var activeThemeId: String
    public var font: FontSettings
    // Слой 2: упорядоченный список правил просмотра поверх датасета.
    public var previewRules: [PreviewRule]

    public init(schemaVersion: Int, settingsVersion: Int, disabledLanguageIds: Set<String>,
                activeThemeId: String, font: FontSettings, previewRules: [PreviewRule]) {
        self.schemaVersion = schemaVersion
        self.settingsVersion = settingsVersion
        self.disabledLanguageIds = disabledLanguageIds
        self.activeThemeId = activeThemeId
        self.font = font
        self.previewRules = previewRules
    }

    public static let currentSchemaVersion = 3

    public static let `default` = ManagerSettings(
        schemaVersion: currentSchemaVersion,
        settingsVersion: 0,
        disabledLanguageIds: [],
        activeThemeId: DefaultThemeIds.dark,
        font: FontSettings(family: nil, size: nil),
        previewRules: []
    )
}
