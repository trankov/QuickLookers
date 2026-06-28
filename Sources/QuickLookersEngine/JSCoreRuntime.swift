import Foundation
import JavaScriptCore

public final class JSCoreRuntime {
    private let context: JSContext

    public init(bundleScript: String) throws {
        guard let ctx = JSContext() else { throw EngineError.contextCreationFailed }
        self.context = ctx

        var thrown: JSValue?
        ctx.exceptionHandler = { _, exc in thrown = exc }
        ctx.evaluateScript(bundleScript)
        if let exc = thrown {
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
        var thrown: JSValue?
        context.exceptionHandler = { _, exc in thrown = exc }
        guard let result = fn.call(withArguments: args) else {
            throw EngineError.callFailed(functionName)
        }
        if let exc = thrown {
            throw EngineError.jsException(exc.toString() ?? "unknown")
        }
        return result
    }
}
