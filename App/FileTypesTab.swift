import SwiftUI

/// Слой 2 — просмотр в Finder, тумблер на язык. Список — из объявленных типов.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        // List (а не grouped-Form): grouped-Form на macOS центрирует содержимое
        // с максимальной шириной и не растёт с окном; List занимает всю ширину.
        List {
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
                    // В List тогл по умолчанию — чекбокс; возвращаем минимальный
                    // переключатель (иначе он крупная «нашлёпка»).
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(!model.isLanguageOn(row.id)) // выключенный на вкладке 1 язык неактивен
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
