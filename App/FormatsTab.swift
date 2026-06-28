import SwiftUI

/// Слой 1 — библиотека: какие языки умеем красить (opt-out).
struct FormatsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Языки") {
                ForEach(model.catalog.languages) { lang in
                    Toggle(lang.displayName, isOn: Binding(
                        get: { model.isLanguageOn(lang.id) },
                        set: { model.setLanguageOn(lang.id, $0) }))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
