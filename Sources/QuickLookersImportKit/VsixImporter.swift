import Foundation

public enum ImportError: Error { case notArchive, noManifest, noContributions }

/// Оркестрация импорта: .vsix → артефакты (темы/грамматики) + пропуски с причинами.
public struct VsixImporter {
    private let bundledGrammarsDir: URL
    private let reader = ZipReader()
    public init(bundledGrammarsDir: URL) { self.bundledGrammarsDir = bundledGrammarsDir }

    public func callAsFunction(vsixData: Data) throws -> ImportResult {
        let names: [String]
        do { names = try reader.entryNames(in: vsixData) }
        catch { throw ImportError.notArchive }
        guard names.contains("extension/package.json"),
              let pkg = try reader.entry("extension/package.json", in: vsixData)
        else { throw ImportError.noManifest }

        let manifest: VsixManifest
        do { manifest = try VsixManifest.parse(packageJSON: pkg) }
        catch ManifestError.noContributions { throw ImportError.noContributions }
        catch { throw ImportError.noManifest }

        var artifacts: [ImportArtifact] = []
        var skips: [ImportSkip] = []
        var themeSlugs = Set<String>()

        // Темы.
        for t in manifest.themes {
            guard let raw = (try? reader.entry("extension/" + clean(t.path), in: vsixData)) ?? nil else {
                skips.append(.init(item: "тема «\(t.label)»", reason: "нет файла \(t.path)")); continue
            }
            let n = ThemeNormalizer.normalize(label: t.label, uiTheme: t.uiTheme,
                                              themeJSON: raw, existingSlugs: themeSlugs)
            themeSlugs.insert(n.id)
            artifacts.append(.init(kind: .theme, id: n.id, displayName: n.displayName,
                                   isDark: n.isDark, json: n.json))
        }

        // Сырые грамматики по language (для дотягивания вложенных-сиблингов).
        var siblings: [String: Data] = [:]
        let normalizer = GrammarNormalizer(bundledGrammarsDir: bundledGrammarsDir)
        for g in manifest.grammars {
            guard let lang = g.language else { continue }
            if let raw = (try? reader.entry("extension/" + clean(g.path), in: vsixData)) ?? nil,
               let json = try? normalizer.toJSON(raw, path: g.path) {
                siblings[lang] = json
            }
        }

        // Грамматики (только с language).
        for g in manifest.grammars {
            guard let lang = g.language else {
                skips.append(.init(item: "грамматика \(g.path)", reason: "инъекция (injectTo) — пропущено"))
                continue
            }
            guard let raw = siblings[lang] else {
                skips.append(.init(item: "грамматика «\(lang)»", reason: "нет/битый файл \(g.path)")); continue
            }
            guard let out = try? normalizer.normalize(languageId: lang, grammarJSON: raw,
                                                      embeddedLanguageIds: g.embeddedLanguageIds,
                                                      siblingGrammars: siblings) else {
                skips.append(.init(item: "грамматика «\(lang)»", reason: "не разобралась")); continue
            }
            let display = manifest.languageDisplayNames[lang] ?? lang
            artifacts.append(.init(kind: .grammar, id: lang, displayName: display, isDark: false, json: out))
        }

        return ImportResult(artifacts: artifacts, skips: skips)
    }

    /// Путь из package.json часто начинается с "./" — убираем для склейки с "extension/".
    private func clean(_ path: String) -> String {
        path.hasPrefix("./") ? String(path.dropFirst(2)) : path
    }
}
