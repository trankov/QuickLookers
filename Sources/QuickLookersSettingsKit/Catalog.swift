public struct LanguageInfo: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct ThemeInfo: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let isDark: Bool
    public init(id: String, displayName: String, isDark: Bool) {
        self.id = id
        self.displayName = displayName
        self.isDark = isDark
    }
}

public struct Catalog: Equatable {
    public let languages: [LanguageInfo]
    public let themes: [ThemeInfo]
    public init(languages: [LanguageInfo], themes: [ThemeInfo]) {
        self.languages = languages
        self.themes = themes
    }
}
