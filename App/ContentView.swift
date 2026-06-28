import SwiftUI

struct ContentView: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        VStack(spacing: 0) {
            if let warning = model.warning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TabView {
                FormatsTab(model: model)
                    .tabItem { Label("Форматы подсветки", systemImage: "paintbrush") }
                ThemesTab(model: model)
                    .tabItem { Label("Темы", systemImage: "circle.lefthalf.filled") }
                FileTypesTab(model: model)
                    .tabItem { Label("Сопоставление", systemImage: "doc.text") }
            }
        }
        .frame(width: 460, height: 360)
    }
}
