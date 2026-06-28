import XCTest
@testable import QuickLookersEngine

final class PerformanceTests: XCTestCase {
    /// Спайк по бюджету производительности (см. дизайн-документ).
    ///
    /// Меряет холодный (с загрузкой грамматики/темы) и тёплый (всё загружено)
    /// показ и печатает цифры. Это измеритель, а не CI-ворота: жёсткого порога
    /// бюджета здесь нет намеренно — оптимизации показа (кэш готового HTML,
    /// обрезка первого экрана, возможный WASM-движок регулярок) живут в других
    /// подсистемах и ещё не подключены.
    ///
    /// Зафиксированные цифры и анализ: docs/superpowers/notes/2026-06-28-engine-benchmark.md
    /// Ориентир бюджета — ~100 мс на типичном файле. Реальный «голый» движок на
    /// 200 строках Swift: cold≈440 мс, warm≈190 мс (release). Свободный потолок
    /// ниже — лишь страховка от катастрофической регрессии (например, потери
    /// кэша подсветчиков и пересборки на каждый показ).
    func test_warmHighlightMeasured() throws {
        let engine = try QuickLookersEngineFactory.makeDefault()
        let code = String(repeating: "let value = compute(x: 1, y: 2)\n", count: 200)
        let req = HighlightRequest(code: code, languageId: "swift", themeId: "dark-plus")

        let coldStart = Date()
        _ = try engine.highlightToHTML(req)              // холодный: грузит грамматику/тему
        let cold = Date().timeIntervalSince(coldStart) * 1000

        let warmStart = Date()
        _ = try engine.highlightToHTML(req)              // тёплый: всё уже загружено
        let warm = Date().timeIntervalSince(warmStart) * 1000

        print(String(format: "cold=%.1fms warm=%.1fms (budget ~100ms)", cold, warm))

        // Санити-потолок, а не бюджет: тёплый показ должен быть кратно быстрее
        // холодного. Срабатывает только при катастрофической регрессии.
        XCTAssertLessThan(warm, cold, "тёплый показ не быстрее холодного — потерян кэш подсветчиков")
        XCTAssertLessThan(warm, 1000.0, "тёплый показ ушёл далеко за любые ожидания")
    }
}
