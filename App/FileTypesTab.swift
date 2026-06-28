import SwiftUI

/// Слой 2 — просмотр в Finder, тумблер на язык. Список — из объявленных типов.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Просмотр в Finder") {
                ForEach(model.fileTypeRows) { row in
                    Toggle(isOn: Binding(
                        get: { model.isPreviewOn(row.id) },
                        set: { model.setPreviewOn(row.id, $0) })) {
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
