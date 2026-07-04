import Foundation

public final class ShikiEngine: HighlightEngine {
    private let runtime: JSCoreRuntime
    private let grammars: GrammarProvider
    private let themes: ThemeProvider
    private var loadedLanguages = Set<String>()
    private var loadedThemes = Set<String>()

    public init(runtime: JSCoreRuntime, grammars: GrammarProvider, themes: ThemeProvider) {
        self.runtime = runtime
        self.grammars = grammars
        self.themes = themes
    }

    public func highlightToHTML(_ request: HighlightRequest) throws -> String {
        if !loadedLanguages.contains(request.languageId) {
            let json = try grammars.grammarJSON(languageId: request.languageId)
            try runtime.registerLanguage(json: Self.forcingMainName(json, to: request.languageId))
            loadedLanguages.insert(request.languageId)
        }
        if !loadedThemes.contains(request.themeId) {
            try runtime.registerTheme(json: themes.themeJSON(themeId: request.themeId))
            loadedThemes.insert(request.themeId)
        }
        return try runtime.highlight(code: request.code,
                                     language: request.languageId,
                                     theme: request.themeId)
    }

    /// Инвариант: грамматика, загружаемая как язык `id`, регистрируется под `id`.
    /// Движок регистрирует грамматику по её полю `name`, а ищет по id → у бандловых
    /// это совпадает (`name == id`), но импортированные из `.vsix` держат витринное
    /// имя VS Code («Django HTML» вместо `django-html`) → показ падает
    /// `lang not registered`. Приводим `name` ГЛАВНОЙ грамматики к id; вложенные
    /// не трогаем — на них ссылаются по их именам. Грамматика всегда массив
    /// [главная + вложенные]; главная — та, чьё `name` уже == id (тогда no-op),
    /// иначе первый элемент (соглашение массива). При сбое разбора — JSON как есть.
    static func forcingMainName(_ json: String, to id: String) -> String {
        guard let data = json.data(using: .utf8),
              var arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !arr.isEmpty,
              !arr.contains(where: { ($0["name"] as? String) == id }) else { return json }
        arr[0]["name"] = id
        guard let out = try? JSONSerialization.data(withJSONObject: arr),
              let s = String(data: out, encoding: .utf8) else { return json }
        return s
    }
}
