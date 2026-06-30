import Foundation
import QuickLookersImportKit

/// Находит VS Code-подобные редакторы в каталоге приложений по product.json
/// (манифест сборки Code-OSS). Маркер: product.json парсится и содержит
/// nameShort + nameLong + dataFolderName. По bundleId НЕ ориентируемся
/// (у Cursor он com.todesktop.*).
public enum EditorScanner {
    public static func scan(applicationsDir: URL) -> [DetectedEditor] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: applicationsDir,
                  includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        var result: [DetectedEditor] = []
        for app in entries where app.pathExtension == "app" {
            let pj = app.appendingPathComponent("Contents/Resources/app/product.json")
            guard let data = try? Data(contentsOf: pj),
                  let obj = try? JSONCParser.object(from: data) as? [String: Any],
                  let nameShort = obj["nameShort"] as? String,
                  let nameLong = obj["nameLong"] as? String,
                  let dataFolderName = obj["dataFolderName"] as? String
            else { continue }
            result.append(DetectedEditor(appURL: app, nameShort: nameShort,
                                         nameLong: nameLong, dataFolderName: dataFolderName))
        }
        return result.sorted { $0.nameLong < $1.nameLong }
    }
}
