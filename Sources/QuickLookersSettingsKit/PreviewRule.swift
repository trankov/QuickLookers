import Foundation

/// Что делать с файлом, попавшим под шаблон.
public enum RuleAction: Codable, Equatable {
    /// Красить подсветкой этого языка.
    case assign(languageId: String)
    /// Не подсвечивать (нейтральный показ поверх дефолта).
    case neutral
}

/// Правило просмотра пользователя: «файлы под шаблоном → действие».
public struct PreviewRule: Codable, Equatable, Identifiable {
    public var id: UUID
    public var pattern: String
    public var action: RuleAction
    public var isEnabled: Bool

    public init(id: UUID = UUID(), pattern: String, action: RuleAction, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.action = action
        self.isEnabled = isEnabled
    }
}
