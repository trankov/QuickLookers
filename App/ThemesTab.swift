import SwiftUI
import QuickLookersSettingsKit
import QuickLookersImportKit

/// Выбор темы: следовать за системой (светлая+тёмная) либо фиксированная.
struct ThemesTab: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var importModel: ImportModel
    @State private var errorText: String?

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
                    if let outcome = importModel.runImport() {
                        if outcome.didChange { model.reloadCatalog(); errorText = nil }
                        else { errorText = outcome.errorText }
                    }
                }
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
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
                                errorText = nil
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
