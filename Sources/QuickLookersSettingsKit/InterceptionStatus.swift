import Foundation

/// Сможет ли Finder вообще позвать нас на файл с таким расширением (Слой A).
public enum InterceptionStatus: Equatable {
    /// Файл дойдёт до нас — правило сработает.
    case intercepted
    /// Система отдала расширение настоящему не-коду (видео/архив/…), мы его не
    /// объявляли — правило не сработает. Имя типа для пояснения пользователю.
    case systemNonCode(typeName: String)
    /// Система расширение не знает и в нашем списке перехвата его нет —
    /// правило не сработает без обновления приложения.
    case unknownNotDeclared
}

/// Что система думает о расширении (мост к UTType — заполняет вызывающая сторона).
public struct SystemTypeInfo: Equatable {
    public var identifier: String
    public var isDynamic: Bool
    public var conformsToPlainText: Bool
    public var localizedName: String?
    public init(identifier: String, isDynamic: Bool, conformsToPlainText: Bool, localizedName: String?) {
        self.identifier = identifier
        self.isDynamic = isDynamic
        self.conformsToPlainText = conformsToPlainText
        self.localizedName = localizedName
    }
}

/// Наш объявленный набор перехвата, прочитанный из бандла.
public struct DeclaredInterceptSet: Equatable {
    /// Свободные (dyn.*) расширения из UTExportedTypeDeclarations хоста (lower).
    public var exportedExtensions: Set<String>
    /// Точные листовые UTI из QLSupportedContentTypes расширения.
    public var systemUTIs: Set<String>
    /// Объявлен ли невод public.plain-text (ловит системно-текстовые типы).
    public var hasPlainTextDragnet: Bool
    public init(exportedExtensions: Set<String>, systemUTIs: Set<String>, hasPlainTextDragnet: Bool) {
        self.exportedExtensions = exportedExtensions
        self.systemUTIs = systemUTIs
        self.hasPlainTextDragnet = hasPlainTextDragnet
    }
}

/// Чистая классификация: перехватим / система-не-код / неизвестно-и-не-объявлено.
public func interceptionStatus(forExtension ext: String,
                               systemType: SystemTypeInfo?,
                               declared: DeclaredInterceptSet) -> InterceptionStatus {
    let e = ext.lowercased()
    if declared.exportedExtensions.contains(e) { return .intercepted }

    guard let t = systemType, !t.isDynamic else { return .unknownNotDeclared }

    if declared.systemUTIs.contains(t.identifier) { return .intercepted }
    if declared.hasPlainTextDragnet && t.conformsToPlainText { return .intercepted }
    return .systemNonCode(typeName: t.localizedName ?? t.identifier)
}
