/// Один объявленный тип: UTI в Info.plist, расширение файла, целевой язык.
public struct DeclaredType: Equatable {
    public let uti: String
    public let pathExtension: String
    public let languageId: String

    public init(uti: String, pathExtension: String, languageId: String) {
        self.uti = uti
        self.pathExtension = pathExtension
        self.languageId = languageId
    }
}

/// Граница Слоя 2: что объявлено в QLSupportedContentTypes расширения.
/// В этом срезе статично; позже — из конфигурации.
///
/// UTI получены резолвером `UTType(filenameExtension:)` на macOS 26 (Darwin 25.5.0).
///
/// ВАЖНО — машинная зависимость. Резолвер запускался на dev-машине с кучей
/// установленных инструментов. Базовые системные — только `public.*`
/// (python/c/cpp/swift/php/ruby/perl/yaml/toml/json/sql/tsx) и
/// `com.netscape.javascript-source`. Вендорные reverse-DNS — `org.go.source`,
/// `org.rust-lang.rust`, `org.scala.source`, `org.vuejs.vue`, `org.nodejs.cjs`,
/// `com.microsoft.csharp-source`, `com.sun.java-source`, `com.adobe.jsx` —
/// существуют в LaunchServices, ПОТОМУ ЧТО их зарегистрировало установленное
/// приложение/тулчейн. На чистой macOS без него файл получит другой тип
/// (`public.plain-text`/`dyn.*`), и перехват не сработает. Это принято
/// осознанно (прагматичная стратегия: работает на нашей машине; дистрибутив-
/// робастность — через собственные `UTExportedTypeDeclarations`, позже).
/// Отдельно: `com.adobe.jsx` семантически — Adobe ExtendScript, а не React JSX
/// (как и исключённый сторонний `org.sbarex.dart`).
///
/// Расширения без стабильного системного UTI — для Task 5 (нужен собственный UTI):
///   - ts  → public.mpeg-2-transport-stream  (конфликт: MPEG-2, не TypeScript)
///   - r   → com.apple.rez-source            (конфликт: Apple Rez, не R-язык)
///   - kt  → dyn.ah62d4rv4ge8007a            (динамический, нестабилен)
///   - kts → dyn.ah62d4rv4ge8007dx           (динамический, нестабилен)
///   - dart → org.sbarex.dart               (сторонний UTI от sbarex, не системный)
///   - graphql → dyn.ah62d4rv4ge80s6xbsbyhc5a (динамический)
///   - gql    → dyn.ah62d4rv4ge80s6pq         (динамический)
///   - dockerfile → перехват по имени файла, не расширению
public enum DeclaredTypes {
    public static let all: [DeclaredType] = [
        // Python
        DeclaredType(uti: "public.python-script",         pathExtension: "py",    languageId: "python"),

        // JavaScript / Node
        DeclaredType(uti: "com.netscape.javascript-source", pathExtension: "js",   languageId: "javascript"),
        DeclaredType(uti: "com.netscape.javascript-source", pathExtension: "mjs",  languageId: "javascript"),
        DeclaredType(uti: "org.nodejs.cjs",               pathExtension: "cjs",   languageId: "javascript"),

        // TypeScript: .ts → UTI конфликтует с MPEG-2 (Task 5)
        DeclaredType(uti: "public.tsx",                   pathExtension: "tsx",   languageId: "tsx"),
        DeclaredType(uti: "com.adobe.jsx",                pathExtension: "jsx",   languageId: "jsx"),

        // C / C++
        DeclaredType(uti: "public.c-source",              pathExtension: "c",     languageId: "c"),
        DeclaredType(uti: "public.c-header",              pathExtension: "h",     languageId: "c"),
        DeclaredType(uti: "public.c-plus-plus-source",    pathExtension: "cpp",   languageId: "cpp"),
        DeclaredType(uti: "public.c-plus-plus-source",    pathExtension: "cc",    languageId: "cpp"),
        DeclaredType(uti: "public.c-plus-plus-source",    pathExtension: "cxx",   languageId: "cpp"),
        DeclaredType(uti: "public.c-plus-plus-header",    pathExtension: "hpp",   languageId: "cpp"),
        DeclaredType(uti: "public.c-plus-plus-header",    pathExtension: "hh",    languageId: "cpp"),

        // JVM и другие компилируемые
        DeclaredType(uti: "com.sun.java-source",          pathExtension: "java",  languageId: "java"),
        DeclaredType(uti: "org.go.source",                pathExtension: "go",    languageId: "go"),
        DeclaredType(uti: "org.rust-lang.rust",           pathExtension: "rs",    languageId: "rust"),
        DeclaredType(uti: "public.swift-source",          pathExtension: "swift", languageId: "swift"),
        DeclaredType(uti: "com.microsoft.csharp-source",  pathExtension: "cs",    languageId: "csharp"),
        DeclaredType(uti: "public.php-script",            pathExtension: "php",   languageId: "php"),
        DeclaredType(uti: "public.ruby-script",           pathExtension: "rb",    languageId: "ruby"),

        // Kotlin: kt/kts → динамические UTI (Task 5)
        // Dart: dart → org.sbarex.dart (сторонний UTI, Task 5)

        // Scala
        DeclaredType(uti: "org.scala.source",             pathExtension: "scala", languageId: "scala"),
        DeclaredType(uti: "org.scala.source",             pathExtension: "sc",    languageId: "scala"),

        // R: .r → com.apple.rez-source (конфликт: Apple Rez, Task 5)

        // Perl
        DeclaredType(uti: "public.perl-script",           pathExtension: "pl",    languageId: "perl"),
        DeclaredType(uti: "public.perl-script",           pathExtension: "pm",    languageId: "perl"),

        // Веб / шаблоны
        DeclaredType(uti: "org.vuejs.vue",                pathExtension: "vue",   languageId: "vue"),

        // Конфигурационные форматы
        DeclaredType(uti: "public.yaml",                  pathExtension: "yaml",  languageId: "yaml"),
        DeclaredType(uti: "public.yaml",                  pathExtension: "yml",   languageId: "yaml"),
        DeclaredType(uti: "public.toml",                  pathExtension: "toml",  languageId: "toml"),
        DeclaredType(uti: "public.json",                  pathExtension: "json",  languageId: "json"),

        // Базы данных и API
        DeclaredType(uti: "org.iso.sql",                  pathExtension: "sql",   languageId: "sql"),

        // GraphQL: graphql/gql → динамические UTI (Task 5)
        // Docker: перехват по имени файла Dockerfile (Task 5)
    ]

    /// Язык для расширения файла среди объявленных типов (или nil).
    public static func languageId(forPathExtension ext: String) -> String? {
        let lower = ext.lowercased()
        return all.first { $0.pathExtension == lower }?.languageId
    }
}

/// Язык включён в библиотеке (Слой 1), если он не в множестве выключенных.
public func isLanguageEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    !settings.disabledLanguageIds.contains(id)
}

/// Язык показывается в Finder, если он включён и не убран из просмотра.
public func isPreviewEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    isLanguageEnabled(id, settings: settings)
        && !settings.previewDisabledLanguageIds.contains(id)
}

/// Язык, которым красить файл по пробелу, или nil → отдать системе.
public func previewLanguageId(forPathExtension ext: String, settings: ManagerSettings) -> String? {
    guard let lang = DeclaredTypes.languageId(forPathExtension: ext) else { return nil }
    guard isPreviewEnabled(lang, settings: settings) else { return nil }
    return lang
}
