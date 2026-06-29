import Foundation

/// Публичный доступ к каталогам встроенных ресурсов движка.
/// Потребители (приложение, расширение) строят из них каталог настроек,
/// не завися от внутренней структуры Bundle.module.
public enum QuickLookersEngineResources {
    public static func grammarsDirectory() throws -> URL { try resourceDirectory("grammars") }
    public static func themesDirectory() throws -> URL { try resourceDirectory("themes") }

    /// URL'ы встроенных сайдкар-каталогов (пусто, если сайдкар не собран —
    /// тогда потребитель откатывается на обход директорий). Список, а не один
    /// URL: потребитель передаёт его в `sidecarURLs` напрямую, а будущий
    /// импортёр `.vsix` дописывает свои сайдкары к этому же списку.
    public static func catalogSidecarURLs() -> [URL] {
        Bundle.module.url(forResource: "catalog", withExtension: "json").map { [$0] } ?? []
    }

    private static func resourceDirectory(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw EngineError.resourceNotFound(name)
        }
        return url
    }
}
