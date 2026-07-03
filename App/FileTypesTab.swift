// App/FileTypesTab.swift
import SwiftUI
import QuickLookersSettingsKit

/// Слой 2 — управление правилами «маска файла → подсветка».
/// По умолчанию видны только правила пользователя; датасет — под поиск, с потолком.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel
    @State private var query = ""
    @State private var editing: PreviewRule?
    @State private var addingNew = false

    private let datasetLimit = 50

    private var results: SettingsModel.RuleSearchResults {
        model.searchRules(query: query, limit: datasetLimit)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Найти расширение, имя файла или язык…", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                }
            }
            .padding(8)

            List {
                if model.userRules.isEmpty && query.isEmpty {
                    emptyState
                } else {
                    mineSection
                    if !query.isEmpty { defaultsSection }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    editing = PreviewRule(pattern: "", action: .assign(languageId: ""))
                    addingNew = true
                } label: { Label("Добавить правило", systemImage: "plus") }
                .padding(8)
            }
            .background(.bar)
        }
        .sheet(item: $editing) { rule in
            AddRuleSheet(model: model, draft: rule) { saved in
                if addingNew { model.addRule(pattern: saved.pattern, action: saved.action) }
                else { model.updateRule(saved) }
                addingNew = false
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Своих правил пока нет.").font(.headline)
            Text("Сотни форматов подсвечиваются по умолчанию. Начните вводить в поиск, "
               + "чтобы найти формат и изменить его, — или добавьте своё правило.")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var mineSection: some View {
        Section("Мои правила") {
            ForEach(results.mine) { rule in
                HStack {
                    Text(rule.pattern).frame(width: 160, alignment: .leading)
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    Text(ruleTarget(rule)).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { model.toggleRule(rule, on: $0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }
                .contextMenu {
                    Button("Изменить") { editing = rule; addingNew = false }
                    Button("Удалить", role: .destructive) { model.deleteRule(rule) }
                }
            }
        }
    }

    private var defaultsSection: some View {
        Section("По умолчанию (показаны первые \(datasetLimit))") {
            ForEach(results.defaults) { match in
                HStack {
                    Text(matchLabel(match)).frame(width: 160, alignment: .leading)
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    Text(model.languageDisplayName(match.languageId)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Изменить") { editing = model.draftOverride(for: match); addingNew = true }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private func ruleTarget(_ rule: PreviewRule) -> String {
        switch rule.action {
        case .assign(let id): return model.languageDisplayName(id)
        case .neutral:        return "не подсвечивать"
        }
    }

    private func matchLabel(_ match: DatasetMatch) -> String {
        switch match.key {
        case .ext(let e):      return ".\(e)"
        case .filename(let f): return f
        }
    }
}
