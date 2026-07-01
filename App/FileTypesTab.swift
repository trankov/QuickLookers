import SwiftUI

/// Слой 2 — таблица правил «расширение/имя файла → язык» с поиском, выбором
/// языка, тумблером просмотра и добавлением своего правила.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel
    @State private var query = ""
    @State private var newExt = ""
    @State private var newLang = ""

    private var rows: [SettingsModel.PreviewRuleRow] {
        let all = model.previewRules
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.key.localizedCaseInsensitiveContains(query)
                || $0.languageName.localizedCaseInsensitiveContains(query)
        }
    }

    private var languageChoices: [(id: String, name: String)] {
        model.catalog.languages
            .map { (id: $0.id, name: $0.displayName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Поиск по расширению или языку", text: $query)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(8)

            List {
                Section("Правила просмотра") {
                    ForEach(rows) { row in
                        HStack {
                            Text(row.isFilename ? row.key : ".\(row.key)")
                                .frame(width: 140, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { row.languageId },
                                set: { model.setRuleLanguage(row, $0) })) {
                                ForEach(languageChoices, id: \.id) { Text($0.name).tag($0.id) }
                            }
                            .labelsHidden()
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { model.isRuleOn(row) },
                                set: { model.setRuleOn(row, $0) }))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .disabled(!model.isLanguageOn(row.languageId))
                        }
                    }
                }

                Section("Добавить своё правило") {
                    HStack {
                        TextField(".расширение", text: $newExt)
                            .frame(width: 140)
                        Picker("", selection: $newLang) {
                            Text("— язык —").tag("")
                            ForEach(languageChoices, id: \.id) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden()
                        Spacer()
                        Button("Добавить") {
                            model.addExtensionRule(ext: newExt, languageId: newLang)
                            newExt = ""; newLang = ""
                        }
                        .disabled(newExt.isEmpty || newLang.isEmpty)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
