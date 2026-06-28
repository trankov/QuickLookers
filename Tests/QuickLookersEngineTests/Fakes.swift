import Foundation
@testable import QuickLookersEngine

final class CountingGrammarProvider: GrammarProvider {
    let inner: GrammarProvider
    private(set) var calls: [String] = []
    init(_ inner: GrammarProvider) { self.inner = inner }
    func grammarJSON(languageId: String) throws -> String {
        calls.append(languageId)
        return try inner.grammarJSON(languageId: languageId)
    }
}
