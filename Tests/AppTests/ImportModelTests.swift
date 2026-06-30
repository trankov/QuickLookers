import XCTest
import QuickLookersImportKit
@testable import QuickLookers

/// message(for:) — единственный кусок ImportModel, не завязанный на NSOpenPanel
/// или реальный App Group контейнер; остальные методы (runImport, importFile,
/// remove, scanEditors, importFromEditor) трогают либо UI, либо настоящий
/// общий контейнер пользователя и намеренно не покрыты автотестами здесь.
@MainActor
final class ImportModelMessageTests: XCTestCase {
    func test_message_notArchive() {
        XCTAssertEqual(ImportModel.message(for: .notArchive), "Это не похоже на файл расширения .vsix.")
    }

    func test_message_tooLarge() {
        XCTAssertEqual(ImportModel.message(for: .tooLarge), "Файл слишком большой или повреждён.")
    }

    func test_message_noManifest() {
        XCTAssertEqual(ImportModel.message(for: .noManifest), "В расширении не найден package.json.")
    }

    func test_message_noContributions() {
        XCTAssertEqual(ImportModel.message(for: .noContributions), "В расширении нет тем и грамматик для импорта.")
    }
}
