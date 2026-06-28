import Foundation

public struct HighlightRequest: Equatable, Sendable {
    public let code: String
    public let languageId: String
    public let themeId: String

    public init(code: String, languageId: String, themeId: String) {
        self.code = code
        self.languageId = languageId
        self.themeId = themeId
    }
}

public enum EngineError: Error, Equatable {
    case contextCreationFailed
    case scriptEvaluation(String)
    case missingFunction(String)
    case callFailed(String)
    case jsException(String)
    case unexpectedResult
    case resourceNotFound(String)
}

public protocol HighlightEngine: AnyObject {
    func highlightToHTML(_ request: HighlightRequest) throws -> String
}
