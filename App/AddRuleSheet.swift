// App/AddRuleSheet.swift
import SwiftUI
import QuickLookersSettingsKit

/// Лист добавления/правки правила просмотра: шаблон, справка о дефолте, статус
/// перехвата, выбор «язык / не подсвечивать» и поиск-выбор языка по живому каталогу.
struct AddRuleSheet: View {
    @ObservedObject var model: SettingsModel
    /// Правило для правки (черновик или существующее). id сохраняется при обновлении.
    @State var draft: PreviewRule
    let onSave: (PreviewRule) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var highlight: Bool
    @State private var languageId: String
    @State private var languageQuery = ""

    init(model: SettingsModel, draft: PreviewRule, onSave: @escaping (PreviewRule) -> Void) {
        self.model = model
        self._draft = State(initialValue: draft)
        self.onSave = onSave
        if case .assign(let id) = draft.action {
            self._highlight = State(initialValue: true)
            self._languageId = State(initialValue: id)
        } else {
            self._highlight = State(initialValue: false)
            self._languageId = State(initialValue: "")
        }
    }

    private var languages: [(id: String, name: String)] {
        let all = model.catalog.languages
            .map { (id: $0.id, name: $0.displayName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !languageQuery.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(languageQuery)
            || $0.id.localizedCaseInsensitiveContains(languageQuery) }
    }

    private var canSave: Bool {
        !draft.pattern.trimmingCharacters(in: .whitespaces).isEmpty && (!highlight || !languageId.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlighting rule").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Name/extension pattern to highlight", text: $draft.pattern)
                    .textFieldStyle(.roundedBorder)
                Text("* = any characters · ? = 1 character · ~ = 1 optional · / = escape (/~, /*, /?)")
                    .font(.caption2).foregroundStyle(.tertiary)
                Text(defaultHint).font(.caption).foregroundStyle(.secondary)
                if let status = statusHint {
                    Label(status.text, systemImage: status.icon)
                        .font(.caption).foregroundStyle(status.color)
                }
            }

            Picker("", selection: $highlight) {
                Text("Highlight").tag(true)
                Text("Disable highlighting").tag(false)
            }
            .pickerStyle(.segmented).labelsHidden()

            if highlight {
                VStack(spacing: 4) {
                    TextField("Find a highlighting format…", text: $languageQuery)
                        .textFieldStyle(.roundedBorder)
                    List(languages, id: \.id, selection: Binding(
                        get: { languageId },
                        set: { languageId = $0 ?? "" })) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                    .frame(height: 160)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    draft.action = highlight ? .assign(languageId: languageId) : .neutral
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var defaultHint: String {
        switch model.currentDefault(forPattern: draft.pattern) {
        case .language(let id): return String(localized: "Now: \(model.languageDisplayName(id))")
        case .neutral:          return String(localized: "Now: neutral (no rule)")
        case .indeterminate:    return " "
        }
    }

    private var statusHint: (text: String, icon: String, color: Color)? {
        guard let status = model.interceptionStatus(forPattern: draft.pattern) else { return nil }
        switch status {
        case .intercepted:
            return (String(localized: "Can be previewed with Space in Finder."), "checkmark.circle", .secondary)
        case .systemNonCode(let name):
            return (String(localized: "Can't preview with Space: the system defines it as '\(name)'."),
                    "exclamationmark.triangle", .orange)
        case .unknownNotDeclared:
            return (String(localized: "This pattern isn't supported: Space preview won't work."),
                    "exclamationmark.triangle", .orange)
        }
    }
}
