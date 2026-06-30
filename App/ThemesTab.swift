import SwiftUI
import AppKit
import QuickLookersSettingsKit
import QuickLookersImportKit
import QuickLookersEditorKit

/// Витрина тем: образец языка → живое превью → шрифт → единый список тем → импорт.
struct ThemesTab: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var importModel: ImportModel
    @StateObject private var fontPanel = FontPanelController()
    @State private var langIndex = 0
    @State private var errorText: String?
    @State private var editorChoices: EditorChoices?
    @State private var hoveredEditorID: String?
    private let bookmarks = BookmarkStore()

    /// Источник данных поповера выбора редактора. Поповер на `item` (а не на Bool +
    /// отдельный @State-массив) пере-презентуется при смене item и читает редакторы
    /// из него — поэтому список не бывает пустым «в первый раз».
    private struct EditorChoices: Identifiable {
        let editors: [DetectedEditor]
        var id: String { editors.map(\.nameShort).joined(separator: "|") }
    }

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

            fontRow

            List(selection: Binding(
                get: { model.settings.activeThemeId },
                set: { id in if let id { model.update { $0.activeThemeId = id } } })) {
                ForEach(model.catalog.themes) { theme in
                    HStack {
                        // Явная галочка у активной темы: выделение List само по себе
                        // неочевидно (теряется при потере фокуса), а тут видно сразу.
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .opacity(theme.id == model.settings.activeThemeId ? 1 : 0)
                        Text(theme.displayName)
                        if model.importedIds.contains(theme.id) {
                            Text("импортирована").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.importedIds.contains(theme.id) {
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

            importRow
        }
        .padding()
    }

    // MARK: - Шрифт

    private var fontRow: some View {
        HStack {
            Text("Шрифт:")
            // Быстрый выбор разумного для кода — список моноширинных.
            Picker("", selection: Binding(
                get: { model.settings.font.family ?? "" },
                set: { v in model.update { $0.font.family = v.isEmpty ? nil : v } })) {
                Text("По умолчанию").tag("")
                // Если активный шрифт не среди установленных моноширинных — добавляем
                // его пунктом (например выбранный через системную панель), иначе Picker
                // не покажет текущий выбор.
                if let f = model.settings.font.family, !MonospaceFonts.families.contains(f) {
                    Text(f).tag(f)
                }
                ForEach(MonospaceFonts.families, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 200)

            // Системная панель «Шрифты» — для всего за пределами списка моноширинных.
            Button("Другие…") {
                let size = model.settings.font.size ?? 12
                let current = model.settings.font.family.flatMap { NSFont(name: $0, size: size) }
                    ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
                fontPanel.present(current: current) { f in
                    model.update {
                        $0.font.family = f.familyName
                        $0.font.size = FontSettings.clampSize(Double(f.pointSize))
                    }
                }
            }

            Spacer()
            Text("Размер:")
            Stepper(value: Binding(
                get: { model.settings.font.size ?? 12 },
                set: { v in model.update { $0.font.size = v } }), in: FontSettings.sizeRange) {
                Text("\(Int(model.settings.font.size ?? 12))")
            }
        }
    }

    // MARK: - Импорт

    private var importRow: some View {
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
                    editorChoices = nil
                } else {
                    errorText = nil
                    editorChoices = EditorChoices(editors: found)
                }
            }
            // arrowEdge .top — поповер раскрывается вверх (кнопка у нижнего края окна).
            .popover(item: $editorChoices, arrowEdge: .top) { choices in
                editorPicker(choices.editors)
            }

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red).lineLimit(2)
            }
            Spacer()
        }
    }

    /// Содержимое поповера: крупный список редакторов с иконками приложений.
    /// Строки на onTapGesture (не Button) — чтобы не было синей рамки фокуса;
    /// выделение даём ховером (HIG 6.1).
    private func editorPicker(_ editors: [DetectedEditor]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(editors, id: \.nameShort) { ed in
                HStack(spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: ed.appURL.path))
                        .resizable().frame(width: 32, height: 32)
                    Text(ed.nameLong)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(hoveredEditorID == ed.nameShort ? Color.accentColor.opacity(0.15) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .onHover { inside in hoveredEditorID = inside ? ed.nameShort : nil }
                .onTapGesture { selectEditor(ed) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(6)
        .frame(minWidth: 260)
    }

    /// Импорт из выбранного редактора: тема (если есть) + шрифт, сразу применить.
    private func selectEditor(_ ed: DetectedEditor) {
        let r = importModel.importFromEditor(ed, store: bookmarks, catalog: model.catalogLookup)
        model.reloadCatalog()
        model.applyEditorResult(themeId: r.themeId, font: r.font)
        errorText = r.message
        editorChoices = nil
    }
}
