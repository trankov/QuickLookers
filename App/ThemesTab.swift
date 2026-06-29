import SwiftUI
import QuickLookersSettingsKit
import QuickLookersImportKit

/// Выбор темы: следовать за системой (светлая+тёмная) либо фиксированная.
struct ThemesTab: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var importModel = ImportModel()

    var body: some View {
        Form {
            Toggle("Следовать за системой", isOn: Binding(
                get: { model.settings.theme.followSystem },
                set: { on in model.update { $0.theme.followSystem = on } }))

            if model.settings.theme.followSystem {
                themePicker("Светлая тема", themes: model.lightThemes, keyPath: \.theme.lightThemeId)
                themePicker("Тёмная тема", themes: model.darkThemes, keyPath: \.theme.darkThemeId)
            } else {
                themePicker("Активная тема", themes: model.catalog.themes, keyPath: \.theme.fixedThemeId)
            }

            Section {
                Button("Импортировать…") {
                    if importModel.runImport() { model.reloadCatalog() }
                }
                if let summary = importModel.summary {
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
            }

            let importedThemes = model.catalog.themes.filter { model.importedIds.contains($0.id) }
            if !importedThemes.isEmpty {
                Section("Импортированные темы") {
                    ForEach(importedThemes) { theme in
                        HStack {
                            Text(theme.displayName)
                            Spacer()
                            Button(role: .destructive) {
                                importModel.remove(kind: .theme, id: theme.id)
                                model.reloadCatalog()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func themePicker(_ title: String, themes: [ThemeInfo],
                             keyPath: WritableKeyPath<ManagerSettings, String>) -> some View {
        Picker(title, selection: Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { id in model.update { $0[keyPath: keyPath] = id } })) {
            ForEach(themes) { theme in
                Text(theme.displayName).tag(theme.id)
            }
        }
    }
}
