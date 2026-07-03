import SwiftUI

struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel
    var body: some View { Text("…").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
