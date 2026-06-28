import Foundation

/// Публичный доступ к каталогам встроенных ресурсов движка.
/// Потребители (приложение, расширение) строят из них каталог настроек,
/// не завися от внутренней структуры Bundle.module.
public enum QuickLookersEngineResources {
    public static func grammarsDirectory() throws -> URL {
        guard let url = Bundle.module.url(forResource: "grammars", withExtension: nil) else {
            throw EngineError.resourceNotFound("grammars")
        }
        return url
    }

    public static func themesDirectory() throws -> URL {
        guard let url = Bundle.module.url(forResource: "themes", withExtension: nil) else {
            throw EngineError.resourceNotFound("themes")
        }
        return url
    }
}
