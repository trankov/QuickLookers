import Foundation
import UniformTypeIdentifiers
import QuickLookersSettingsKit

/// Мост между чистым классификатором перехвата и реальным бандлом/системой.
enum InterceptionDeclarations {
    /// Набор перехвата из Info.plist хоста (экспортные расширения) и расширения
    /// Preview (системные UTI). При недоступности части — деградируем к пустому.
    static func load() -> DeclaredInterceptSet {
        DeclaredInterceptSet(
            exportedExtensions: exportedExtensions(),
            systemUTIs: systemUTIs(),
            hasPlainTextDragnet: systemUTIs().contains("public.plain-text"))
    }

    /// UTType-вердикт системы по расширению.
    static func systemType(forExtension ext: String) -> SystemTypeInfo? {
        guard let t = UTType(filenameExtension: ext) else { return nil }
        return SystemTypeInfo(identifier: t.identifier, isDynamic: t.isDynamic,
                              conformsToPlainText: t.conforms(to: .plainText),
                              localizedName: t.localizedDescription)
    }

    // MARK: - Private

    /// Расширения из UTExportedTypeDeclarations хоста (тип com.quicklookers.source-code).
    private static func exportedExtensions() -> Set<String> {
        guard let decls = Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations") as? [[String: Any]]
        else { return [] }
        var out: Set<String> = []
        for decl in decls {
            guard let tags = decl["UTTypeTagSpecification"] as? [String: Any],
                  let exts = tags["public.filename-extension"] as? [String] else { continue }
            for e in exts { out.insert(e.lowercased()) }
        }
        return out
    }

    /// QLSupportedContentTypes из Info.plist расширения Preview (в PlugIns).
    private static func systemUTIs() -> Set<String> {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: plugins, includingPropertiesForKeys: nil)
        else { return [] }
        for appex in items where appex.pathExtension == "appex" {
            let plist = appex.appendingPathComponent("Contents/Info.plist")
            guard let dict = NSDictionary(contentsOf: plist),
                  let ext = dict["NSExtension"] as? [String: Any],
                  let attrs = ext["NSExtensionAttributes"] as? [String: Any],
                  let types = attrs["QLSupportedContentTypes"] as? [String] else { continue }
            return Set(types)
        }
        return []
    }
}
