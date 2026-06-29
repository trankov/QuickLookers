import Foundation

public struct ImportArtifact: Equatable {
    public enum Kind: String { case grammar, theme }
    public let kind: Kind
    public let id: String
    public let displayName: String
    public let isDark: Bool          // значимо для темы; для грамматики false
    public let json: Data
    public init(kind: Kind, id: String, displayName: String, isDark: Bool, json: Data) {
        self.kind = kind; self.id = id; self.displayName = displayName; self.isDark = isDark; self.json = json
    }
}

public struct ImportSkip: Equatable {
    public let item: String; public let reason: String
    public init(item: String, reason: String) { self.item = item; self.reason = reason }
}

public struct ImportResult: Equatable {
    public let artifacts: [ImportArtifact]; public let skips: [ImportSkip]
    public init(artifacts: [ImportArtifact], skips: [ImportSkip]) { self.artifacts = artifacts; self.skips = skips }
}
