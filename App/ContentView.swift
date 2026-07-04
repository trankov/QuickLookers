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
            ThemesTab(model: model, importModel: importModel)
                .tabItem { Label("Theme", systemImage: "circle.lefthalf.filled") }
            FormatsTab(model: model, importModel: importModel)
                .tabItem { Label("Formats", systemImage: "paintbrush") }
            FileTypesTab(model: model)
                .tabItem { Label("Patterns", systemImage: "eye") }
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
        // Резиновое окно под вертикальную витрину «превью + список». Минимум
        // держит UI пригодным; превью растёт с окном (Human Interface Guidlines 2.1).
        .frame(minWidth: 480, idealWidth: 580, maxWidth: .infinity,
               minHeight: 560, idealHeight: 680, maxHeight: .infinity)
    }
}
