import Foundation

public enum ImportError: Error { case notArchive, noManifest, noContributions, tooLarge }

/// Оркестрация импорта: .vsix → артефакты (темы/грамматики) + пропуски с причинами.
public struct VsixImporter {
    private let bundledGrammarsDir: URL
    private let reader: ZipReader
    public init(bundledGrammarsDir: URL) {
        self.bundledGrammarsDir = bundledGrammarsDir
        self.reader = ZipReader()
    }
    /// Только для тестов: внедрить ZipReader с урезанными потолками, чтобы проверить
    /// маппинг ZipError.tooManyEntries/entryTooLarge → ImportError.tooLarge без гигантских фикстур.
    init(bundledGrammarsDir: URL, reader: ZipReader) {
        self.bundledGrammarsDir = bundledGrammarsDir
        self.reader = reader
    }

    public func callAsFunction(vsixData: Data) throws -> ImportResult {
        let names: [String]
        do { names = try reader.entryNames(in: vsixData) }
        catch ZipError.tooManyEntries, ZipError.entryTooLarge { throw ImportError.tooLarge }
        catch { throw ImportError.notArchive }
        guard names.contains("extension/package.json") else { throw ImportError.noManifest }
        let pkg = try readManifestEntry(in: vsixData)

        let manifest: VsixManifest
        do { manifest = try VsixManifest.parse(packageJSON: pkg) }
        catch ManifestError.noContributions { throw ImportError.noContributions }
        catch { throw ImportError.noManifest }

        var artifacts: [ImportArtifact] = []
        var skips: [ImportSkip] = []
        var themeSlugs = Set<String>()

        // Темы.
        for t in manifest.themes {
            guard let raw = readEntry(t.path, in: vsixData) else {
                skips.append(.init(item: "тема «\(t.label)»", reason: "нет файла \(t.path)")); continue
            }
            // Темы расширений бывают JSONC → приводим к строгому JSON перед хранением/движком.
            let strict = (try? JSONCParser.toStrictJSON(raw)) ?? raw
            let n = ThemeNormalizer.normalize(label: t.label, uiTheme: t.uiTheme,
                                              themeJSON: strict, existingSlugs: themeSlugs)
            guard isSafeImportID(n.id) else {
                skips.append(.init(item: "тема «\(t.label)»", reason: "недопустимый идентификатор"))
                continue
            }
            themeSlugs.insert(n.id)
            artifacts.append(.init(kind: .theme, id: n.id, displayName: n.displayName,
                                   isDark: n.isDark, json: n.json))
        }

        // Сырые грамматики по language (для дотягивания вложенных-сиблингов).
        var siblings: [String: Data] = [:]
        let normalizer = GrammarNormalizer(bundledGrammarsDir: bundledGrammarsDir)
        for g in manifest.grammars {
            guard let lang = g.language else { continue }
            if let raw = readEntry(g.path, in: vsixData),
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
            guard isSafeImportID(lang) else {
                skips.append(.init(item: "грамматика «\(lang)»", reason: "недопустимый идентификатор"))
                continue
            }
            guard let grammarJSON = siblings[lang] else {
                skips.append(.init(item: "грамматика «\(lang)»", reason: "нет/битый файл \(g.path)")); continue
            }
            guard let out = try? normalizer.normalize(languageId: lang, grammarJSON: grammarJSON,
                                                      embeddedLanguageIds: g.embeddedLanguageIds,
                                                      siblingGrammars: siblings) else {
                skips.append(.init(item: "грамматика «\(lang)»", reason: "не разобралась")); continue
            }
            let display = manifest.languageDisplayNames[lang] ?? lang
            artifacts.append(.init(kind: .grammar, id: lang, displayName: display, isDark: false, json: out))
        }

        return ImportResult(artifacts: artifacts, skips: skips)
    }

    /// Содержимое записи .vsix по относительному пути из package.json (с префиксом extension/).
    /// Сырой ZipError (повреждённая/нечитаемая запись) трактуем как nil — наружу из
    /// callAsFunction для отдельных тем/грамматик выходит только пропуск, не падение.
    private func readEntry(_ relPath: String, in data: Data) -> Data? {
        try? reader.entry("extension/" + clean(relPath), in: data)
    }

    /// package.json — обязательная запись, отказ должен быть различим: либо его действительно
    /// нет/он битый (noManifest), либо он превысил потолок ZipReader (tooLarge, зип-бомба).
    /// В отличие от readEntry, тут ZipError.entryTooLarge НЕ проглатывается.
    private func readManifestEntry(in data: Data) throws -> Data {
        do {
            guard let d = try reader.entry("extension/package.json", in: data) else {
                throw ImportError.noManifest
            }
            return d
        } catch ZipError.entryTooLarge {
            throw ImportError.tooLarge
        } catch {
            throw ImportError.noManifest
        }
    }

    /// Путь из package.json часто начинается с "./" — убираем для склейки с "extension/".
    private func clean(_ path: String) -> String {
        path.hasPrefix("./") ? String(path.dropFirst(2)) : path
    }
}
