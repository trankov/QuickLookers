// Scripts/audit-extension-utis.swift
// Запуск: swift Scripts/audit-extension-utis.swift Sources/QuickLookersEngine/Resources/associations.json
import Foundation
import UniformTypeIdentifiers

let path = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/QuickLookersEngine/Resources/associations.json"
struct Assoc: Decodable { struct Lang: Decodable { let id: String; let extensions: [String]?; let filenames: [String]? }
                          let languages: [Lang]; let interceptExtensions: [String]? }
let data = try Data(contentsOf: URL(fileURLWithPath: path))
let assoc = try JSONDecoder().decode(Assoc.self, from: data)

// Уникальные расширения → к какому языку ведут (для отчёта).
// interceptExtensions — расширения без грамматики, перехватываемые ради пользовательских
// правил (дефолтного языка нет → помечаем как «(intercept)»).
var extToLang: [String: String] = [:]
for l in assoc.languages { for e in (l.extensions ?? []) { extToLang[e.lowercased()] = extToLang[e.lowercased()] ?? l.id } }
for e in (assoc.interceptExtensions ?? []) { let k = e.lowercased(); extToLang[k] = extToLang[k] ?? "(intercept)" }

func category(_ ext: String) -> (uti: String, cat: String) {
    guard let t = UTType(filenameExtension: ext) else { return ("nil", "нет типа") }
    let id = t.identifier
    if id.hasPrefix("dyn.") { return (id, "dyn — свой UTI (1b)") }
    if id == "public.data" { return (id, "public.data — невод (2)") }
    if id == "public.plain-text" { return (id, "public.plain-text — уже в неводе") }
    if id == "public.item" || id == "public.content" { return (id, "generic — невод (2)") }
    return (id, "системный лист — объявить (1a)")
}

var own: [String] = [], declare: [(String, String)] = []
for ext in extToLang.keys.sorted() {
    let (uti, cat) = category(ext)
    print("\(ext)\t\(uti)\t\(cat)\t→\(extToLang[ext] ?? "?")")
    if cat.contains("1b") { own.append(ext) }
    if cat.contains("1a") { declare.append((ext, uti)) }
}
print("\n=== 1b свои UTI (dyn) ===\n" + own.joined(separator: ", "))
print("\n=== 1a объявить системный UTI ===")
for (e, u) in declare { print("  .\(e) → \(u)  (\(extToLang[e] ?? "?"))") }

if CommandLine.arguments.contains("--emit-tags") {
    // Только свободные (dyn.*) расширения — готовый flow-массив для public.filename-extension.
    // На ЧИСТОЙ машине список полон: nim и прочий хвост приходят через категорию 1b сами.
    // На машине, где уже собран наш билд, LaunchServices вернёт эти расширения как наш UTI
    // (самоконтаминация) → гнать утилиту ДО сборки / на чистой машине (см. заметку аудита).
    print("[" + own.sorted().joined(separator: ", ") + "]")
}
