import SwiftUI
import QuickLookersSettingsKit
import QuickLookersImportKit
import QuickLookersEditorKit

/// Витрина тем: образец языка → живое превью → шрифт → единый список тем → импорт.
struct ThemesTab: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var importModel: ImportModel
    @State private var langIndex = 0
    @State private var errorText: String?
    @State private var editors: [DetectedEditor] = []
    @State private var showEditorPicker = false
    private let bookmarks = BookmarkStore()

    private var snippets: [(id: String, name: String, code: String)] { PreviewSnippets.all }

    var body: some View {
        VStack(spacing: 10) {
            Picker("Язык образца", selection: $langIndex) {
                ForEach(Array(snippets.enumerated()), id: \.offset) { i, s in Text(s.name).tag(i) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            CodePreviewView(html: model.previewHTML(languageId: snippets[langIndex].id,
                                                    code: snippets[langIndex].code))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(.separator)

            HStack {
                Text("Шрифт:")
                Picker("", selection: Binding(
                    get: { model.settings.font.family ?? "" },
                    set: { v in model.update { $0.font.family = v.isEmpty ? nil : v } })) {
                    Text("По умолчанию").tag("")
                    // Если активный шрифт не среди установленных — добавляем его пунктом,
                    // иначе Picker не покажет текущий выбор.
                    if let f = model.settings.font.family, !MonospaceFonts.families.contains(f) {
                        Text(f).tag(f)
                    }
                    ForEach(MonospaceFonts.families, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 240)

                Spacer()
                Text("Размер:")
                Stepper(value: Binding(
                    get: { model.settings.font.size ?? 12 },
                    set: { v in model.update { $0.font.size = v } }), in: 6...48) {
                    Text("\(Int(model.settings.font.size ?? 12))")
                }
            }

            List(selection: Binding(
                get: { model.settings.activeThemeId },
                set: { id in if let id { model.update { $0.activeThemeId = id } } })) {
                ForEach(model.catalog.themes) { theme in
                    HStack {
                        Text(theme.displayName)
                        if model.importedIds.contains(theme.id) {
                            Text("импортирована").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                importModel.remove(kind: .theme, id: theme.id)
                                model.reloadCatalog(); errorText = nil
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                        }
                    }
                    .tag(theme.id)
                }
            }
            .frame(minHeight: 120)

            HStack {
                Button("Импортировать .vsix…") {
                    if let outcome = importModel.runImport() {
                        if outcome.didChange { model.reloadCatalog(); errorText = nil }
                        else { errorText = outcome.errorText }
                    }
                }
                // Грант на /Applications запрашивается лениво — только по нажатию.
                Button("Из редактора…") {
                    let found = importModel.scanEditors(bookmarks)
                    if found.isEmpty {
                        errorText = "Редакторы не найдены или нет доступа к папке «Программы»."
                    } else {
                        editors = found
                        showEditorPicker = true
                    }
                }
                .confirmationDialog("Из какого редактора взять тему и шрифт?",
                                    isPresented: $showEditorPicker, titleVisibility: .visible) {
                    ForEach(editors, id: \.nameShort) { ed in
                        Button(ed.nameLong) {
                            let r = importModel.importFromEditor(ed, store: bookmarks, catalog: model.catalogLookup)
                            model.reloadCatalog()
                            model.applyEditorResult(themeId: r.themeId, font: r.font)
                            errorText = r.message
                        }
                    }
                    Button("Отмена", role: .cancel) {}
                }

                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
                Spacer()
            }
        }
        .padding()
    }
}
