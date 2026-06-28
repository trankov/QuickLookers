import SwiftUI

@main
struct QuickLookersApp: App {
    var body: some Scene {
        WindowGroup("QuickLookers") {
            VStack(spacing: 8) {
                Text("QuickLookers")
                    .font(.title2)
                Text("Расширение Preview зарегистрировано.\nНажми пробел на файле кода в Finder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 360, height: 160)
        }
    }
}
