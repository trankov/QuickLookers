import SwiftUI
import QuickLookersSettingsKit

/// Слой 2 — просмотр в Finder, тумблер на язык. Список — из объявленных типов.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel

    /// Языки с объявленным типом + их расширения (для пояснения).
    private struct Row: Identifiable {
        let id: String          // languageId
        let displayName: String
        let extensions: String  // ".swift", ".json" …
    }

    private var rows: [Row] {
        let byLanguage = Dictionary(grouping: DeclaredTypes.all, by: { $0.languageId })
        return byLanguage.keys.sorted().map { lang in
            let exts = byLanguage[lang]!.map { ".\($0.pathExtension)" }.joined(separator: ", ")
            let name = model.catalog.languages.first { $0.id == lang }?.displayName ?? lang
            return Row(id: lang, displayName: name, extensions: exts)
        }
    }

    var body: some View {
        Form {
            Section("Просмотр в Finder") {
                ForEach(rows) { row in
                    Toggle(isOn: Binding(
                        get: { model.isPreviewOn(row.id) },
                        set: { on in
                            model.update { s in
                                if on { s.previewDisabledLanguageIds.remove(row.id) }
                                else { s.previewDisabledLanguageIds.insert(row.id) }
                            }
                        })) {
                        VStack(alignment: .leading) {
                            Text(row.displayName)
                            Text(row.extensions).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!model.isLanguageOn(row.id)) // выключенный на вкладке 1 язык неактивен
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
