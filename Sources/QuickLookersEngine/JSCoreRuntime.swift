import Foundation
import JavaScriptCore

public final class JSCoreRuntime {
    private let context: JSContext
    private var lastException: JSValue?

    public init(bundleScript: String) throws {
        guard let ctx = JSContext() else { throw EngineError.contextCreationFailed }
        self.context = ctx

        // Обработчик исключений ставится один раз; JSC вызывает его синхронно
        // во время evaluate/call, поэтому lastException актуален сразу после.
        ctx.exceptionHandler = { [weak self] _, exc in self?.lastException = exc }
        ctx.evaluateScript(bundleScript)
        if let exc = lastException {
            throw EngineError.scriptEvaluation(exc.toString() ?? "unknown")
        }
    }

    public static func loadBundledScript() throws -> String {
        guard let url = Bundle.module.url(forResource: "shiki-bundle", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8) else {
            throw EngineError.resourceNotFound("shiki-bundle.js")
        }
        return script
    }

    public func registerLanguage(json: String) throws { _ = try call("qlRegisterLang", [json]) }
    public func registerTheme(json: String) throws { _ = try call("qlRegisterTheme", [json]) }

    public func highlight(code: String, language: String, theme: String) throws -> String {
        let result = try call("qlHighlight", [code, language, theme])
        guard let html = result.toString() else { throw EngineError.unexpectedResult }
        return html
    }

    @discardableResult
    private func call(_ functionName: String, _ args: [Any]) throws -> JSValue {
        guard let fn = context.objectForKeyedSubscript(functionName), !fn.isUndefined else {
            throw EngineError.missingFunction(functionName)
        }
        lastException = nil
        guard let result = fn.call(withArguments: args) else {
            throw EngineError.callFailed(functionName)
        }
        if let exc = lastException {
            throw EngineError.jsException(exc.toString() ?? "unknown")
        }
        return result
    }
}
