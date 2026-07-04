import XCTest
@testable import QuickLookers

/// Смоук-тест локализации: главный риск связки XcodeGen + String Catalog — при
/// регенерации проект теряет регион `ru` в knownRegions, и русский вариант просто
/// не собирается. Тест ловит этот регресс: оба языка должны реально попасть в бандл.
final class LocalizationTests: XCTestCase {
    func test_bundleShipsEnglishAndRussian() {
        let localizations = Set(Bundle.main.localizations)
        XCTAssertTrue(localizations.contains("en"), "нет английской локализации в бандле: \(localizations)")
        XCTAssertTrue(localizations.contains("ru"), "нет русской локализации в бандле: \(localizations)")
    }
}
