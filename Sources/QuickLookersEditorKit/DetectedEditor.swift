import Foundation

public struct DetectedEditor: Equatable {
    public let appURL: URL
    public let nameShort: String      // папка под ~/Library/Application Support
    public let nameLong: String       // показываемое имя
    public let dataFolderName: String // ".vscode"/".cursor" → ~/<...>/extensions
    public init(appURL: URL, nameShort: String, nameLong: String, dataFolderName: String) {
        self.appURL = appURL; self.nameShort = nameShort
        self.nameLong = nameLong; self.dataFolderName = dataFolderName
    }
}
