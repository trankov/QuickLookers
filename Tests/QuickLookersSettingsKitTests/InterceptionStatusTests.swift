import XCTest
@testable import QuickLookersSettingsKit

final class InterceptionStatusTests: XCTestCase {
    private let declared = DeclaredInterceptSet(
        exportedExtensions: ["kt", "dart", "nim"],
        systemUTIs: ["public.swift-source", "public.mpeg-2-transport-stream", "public.plain-text"],
        hasPlainTextDragnet: true)

    func test_extensionInExportedList_isIntercepted() {
        XCTAssertEqual(
            interceptionStatus(forExtension: "kt", systemType: nil, declared: declared),
            .intercepted)
    }

    func test_unknownToSystem_notDeclared_isUnknown() {
        // .djhtml: система не знает, в списке нет → честно «не перехватим».
        let dyn = SystemTypeInfo(identifier: "dyn.abc", isDynamic: true,
                                 conformsToPlainText: false, localizedName: nil)
        XCTAssertEqual(
            interceptionStatus(forExtension: "djhtml", systemType: dyn, declared: declared),
            .unknownNotDeclared)
    }

    func test_nilSystemType_notDeclared_isUnknown() {
        XCTAssertEqual(
            interceptionStatus(forExtension: "foobar", systemType: nil, declared: declared),
            .unknownNotDeclared)
    }

    func test_systemCodeType_conformsPlainText_isIntercepted() {
        // .swift → public.swift-source, конформит plain-text → невод ловит.
        let t = SystemTypeInfo(identifier: "public.swift-source", isDynamic: false,
                               conformsToPlainText: true, localizedName: "Swift source")
        XCTAssertEqual(
            interceptionStatus(forExtension: "swift", systemType: t, declared: declared),
            .intercepted)
    }

    func test_declaredSystemUTI_evenIfNotPlainText_isIntercepted() {
        // .ts → public.mpeg-2-transport-stream (не текст), но мы намеренно объявили → перехватим.
        let t = SystemTypeInfo(identifier: "public.mpeg-2-transport-stream", isDynamic: false,
                               conformsToPlainText: false, localizedName: "MPEG-2 video")
        XCTAssertEqual(
            interceptionStatus(forExtension: "ts", systemType: t, declared: declared),
            .intercepted)
    }

    func test_systemNonCode_notDeclared_reportsTypeName() {
        // .mts → видео, не объявляли → не сработает.
        let t = SystemTypeInfo(identifier: "public.mpeg-2-video", isDynamic: false,
                               conformsToPlainText: false, localizedName: "MPEG-2 video")
        XCTAssertEqual(
            interceptionStatus(forExtension: "mts", systemType: t, declared: declared),
            .systemNonCode(typeName: "MPEG-2 video"))
    }
}
