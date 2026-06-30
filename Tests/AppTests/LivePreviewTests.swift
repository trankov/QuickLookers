import XCTest
@testable import QuickLookers

final class FragmentCacheTests: XCTestCase {
    func test_fragment_recomputesOnFirstCall() {
        let cache = FragmentCache()
        var calls = 0
        let result = cache.fragment(forKey: "a") { calls += 1; return "<one>" }
        XCTAssertEqual(result, "<one>")
        XCTAssertEqual(calls, 1)
    }

    func test_fragment_reusesCachedValueForSameKey() {
        let cache = FragmentCache()
        var calls = 0
        _ = cache.fragment(forKey: "a") { calls += 1; return "<one>" }
        let second = cache.fragment(forKey: "a") { calls += 1; return "<two>" }
        XCTAssertEqual(second, "<one>")
        XCTAssertEqual(calls, 1)
    }

    func test_fragment_recomputesWhenKeyChanges() {
        let cache = FragmentCache()
        var calls = 0
        _ = cache.fragment(forKey: "a") { calls += 1; return "<one>" }
        let second = cache.fragment(forKey: "b") { calls += 1; return "<two>" }
        XCTAssertEqual(second, "<two>")
        XCTAssertEqual(calls, 2)
    }

    func test_invalidate_forcesRecomputeForSameKey() {
        let cache = FragmentCache()
        var calls = 0
        _ = cache.fragment(forKey: "a") { calls += 1; return "<one>" }
        cache.invalidate()
        let second = cache.fragment(forKey: "a") { calls += 1; return "<two>" }
        XCTAssertEqual(second, "<two>")
        XCTAssertEqual(calls, 2)
    }
}

final class MonospaceFontsTests: XCTestCase {
    func test_families_areSortedWithoutDuplicates() {
        let families = MonospaceFonts.families
        XCTAssertEqual(families, families.sorted())
        XCTAssertEqual(families.count, Set(families).count)
    }
}

@MainActor
final class SettingsModelPreviewHTMLTests: XCTestCase {
    func test_previewHTML_rendersHighlightedFragment() throws {
        let tmp = try makeTempContainer()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let model = SettingsModel(containerURL: tmp)
        let html = model.previewHTML(languageId: "json", code: "{\"a\":1}")

        XCTAssertTrue(html.contains("<pre"))
        XCTAssertTrue(html.contains("shiki"))
        XCTAssertTrue(html.contains("<html"))
    }

    func test_previewHTML_cachesFragmentAcrossCallsWithSameLanguageAndTheme() throws {
        let tmp = try makeTempContainer()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let model = SettingsModel(containerURL: tmp)
        let first = model.previewHTML(languageId: "json", code: "{\"a\":1}")
        // Другой код, тот же язык/тема — фрагмент берётся из кэша (по ключу язык|тема),
        // поэтому подсветка не меняется, хотя бы обёртка (страница) пересобирается.
        let second = model.previewHTML(languageId: "json", code: "{\"b\":2}")
        XCTAssertEqual(first, second)
    }
}
