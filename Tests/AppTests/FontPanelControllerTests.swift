import AppKit
import XCTest
@testable import QuickLookers

@MainActor
final class FontPanelControllerTests: XCTestCase {
    override func tearDown() {
        // present() реально открывает системную панель «Шрифты» — закрываем её,
        // чтобы тесты не оставляли окно висеть между прогонами.
        NSFontPanel.shared.close()
        super.tearDown()
    }

    func test_validModesForFontPanel_restrictsToCollectionFaceSize() {
        let controller = FontPanelController()
        let modes = controller.validModesForFontPanel(NSFontPanel.shared)
        let expected: NSFontPanel.ModeMask = [.collection, .face, .size]
        XCTAssertEqual(modes, expected)
    }

    func test_changeFont_invokesOnChangeCallback() {
        let controller = FontPanelController()
        var received: NSFont?
        let starting = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        controller.present(current: starting) { font in received = font }

        controller.changeFont(NSFontManager.shared)

        // Без реального выбора в панели NSFontManager.convert(_:) не меняет шрифт,
        // но связка target → changeFont → onChange должна сработать хотя бы раз.
        XCTAssertNotNil(received)
    }

    func test_changeFont_withNilSender_doesNothing() {
        let controller = FontPanelController()
        var callCount = 0
        controller.present(current: .monospacedSystemFont(ofSize: 12, weight: .regular)) { _ in callCount += 1 }

        controller.changeFont(nil)

        XCTAssertEqual(callCount, 0)
    }
}
