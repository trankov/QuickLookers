import SwiftUI
import QuickLookersImportKit

/// Слой 1 — библиотека: какие языки умеем красить (opt-out).
struct FormatsTab: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var importModel: ImportModel

    var body: some View {
        Form {
            Section("Языки") {
                ForEach(model.catalog.languages) { lang in
                    HStack {
                        Toggle(lang.displayName, isOn: Binding(
                            get: { model.isLanguageOn(lang.id) },
                            set: { model.setLanguageOn(lang.id, $0) }))
                        if model.importedIds.contains(lang.id) {
                            Button(role: .destructive) {
                                importModel.remove(kind: .grammar, id: lang.id)
                                model.reloadCatalog()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section {
                Button("Импортировать…") {
                    if importModel.runImport() { model.reloadCatalog() }
                }
                if let summary = importModel.summary {
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
