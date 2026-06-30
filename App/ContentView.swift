import SwiftUI
import QuickLookersImportKit

struct ContentView: View {
    @StateObject private var model = SettingsModel()
    @StateObject private var importModel = ImportModel()

    var body: some View {
        // TabView — корень окна, чтобы macOS показал нативную панель вкладок
        // сверху. Предупреждение вешаем через safeAreaInset, не оборачивая
        // TabView в VStack (иначе панель схлопывается в overflow-шеврон «>>»).
        TabView {
            FormatsTab(model: model, importModel: importModel)
                .tabItem { Label("Форматы подсветки", systemImage: "paintbrush") }
            ThemesTab(model: model, importModel: importModel)
                .tabItem { Label("Темы", systemImage: "circle.lefthalf.filled") }
            FileTypesTab(model: model)
                .tabItem { Label("Сопоставление", systemImage: "doc.text") }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let warning = model.warning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
        }
        // Шире, чтобы три подписи вкладок помещались в верхнюю панель и она
        // не сворачивалась в «>>».
        .frame(width: 620, height: 420)
    }
}
