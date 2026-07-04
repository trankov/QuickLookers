import SwiftUI
import QuickLookersSettingsKit
import QuickLookersImportKit

/// Слой 1 — библиотека: какие языки умеем красить (opt-out).
/// Три зоны: поиск сверху, прокручиваемый список (нативный grouped Form),
/// кнопка импорта внизу.
struct FormatsTab: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var importModel: ImportModel
    @State private var query = ""
    @State private var errorText: String?

    /// Языки, отфильтрованные строкой поиска (по названию и id, без учёта регистра).
    private var filteredLanguages: [LanguageInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.catalog.languages }
        return model.catalog.languages.filter {
            $0.displayName.lowercased().contains(q) || $0.id.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Поиск формата подсветки", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

            // List (а не grouped-Form): grouped-Form на macOS центрирует содержимое
            // с максимальной шириной и не растёт с окном; List занимает всю ширину.
            List {
                ForEach(filteredLanguages) { lang in
                    HStack {
                        Toggle(lang.displayName, isOn: Binding(
                            get: { model.isLanguageOn(lang.id) },
                            set: { model.setLanguageOn(lang.id, $0) }))
                        // В List тогл по умолчанию — чекбокс; принудительно швыряем
                        // на переключатель и задаём минимальный размер (иначе
                        // переключатель выходит крупной «нашлёпкой»).
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        if model.importedIds.contains(lang.id) {
                            Button(role: .destructive) {
                                importModel.remove(kind: .grammar, id: lang.id)
                                model.reloadCatalog()
                                errorText = nil
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Удалить импортированный «\(lang.displayName)»")
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button("Импортировать .vsix…") {
                    if let outcome = importModel.runImport() {
                        if outcome.didChange { model.reloadCatalog(); errorText = nil }
                        else { errorText = outcome.errorText }
                    }
                }
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding()
        }
        // Иначе содержимое держит идеальную ширину: при сужении окна сжимается,
        // а при расширении не растёт и оставляет пустую полосу справа.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
