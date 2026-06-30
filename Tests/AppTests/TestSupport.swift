import Foundation

/// Временная директория для `SettingsModel(containerURL:)` — НЕ реальный App Group
/// контейнер пользователя, чтобы прогон тестов не портил настоящие настройки.
func makeTempContainer() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickLookersTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
