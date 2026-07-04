import XCTest
import QuickLookersImportKit
@testable import QuickLookers

/// message(for:) — единственный кусок ImportModel, не завязанный на NSOpenPanel
/// или реальный App Group контейнер; остальные методы (runImport, importFile,
/// remove, scanEditors, importFromEditor) трогают либо UI, либо настоящий
/// общий контейнер пользователя и намеренно не покрыты автотестами здесь.
///
/// Строки теперь локализованы: `String(localized:)` возвращает язык системы, поэтому
/// сверяем с тем же ключом (тоже через `String(localized:)`) — тест проверяет
/// правильность отображения «ошибка → ключ» и не зависит от локали машины.
@MainActor
final class ImportModelMessageTests: XCTestCase {
    func test_message_notArchive() {
        XCTAssertEqual(ImportModel.message(for: .notArchive),
                       String(localized: "This doesn't look like a .vsix extension file."))
    }

    func test_message_tooLarge() {
        XCTAssertEqual(ImportModel.message(for: .tooLarge),
                       String(localized: "The file is too large or corrupted."))
    }

    func test_message_noManifest() {
        XCTAssertEqual(ImportModel.message(for: .noManifest),
                       String(localized: "package.json wasn't found in the extension."))
    }

    func test_message_noContributions() {
        XCTAssertEqual(ImportModel.message(for: .noContributions),
                       String(localized: "The extension has no themes or grammars to import."))
    }
}
