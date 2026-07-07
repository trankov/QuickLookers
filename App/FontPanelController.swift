import AppKit

/// Открывает системную панель «Шрифты» (NSFontPanel) и сообщает выбранный шрифт.
/// Держать ссылку живой, пока панель открыта: NSFontManager НЕ удерживает target,
/// поэтому контроллер хранится во вью как @StateObject.
final class FontPanelController: NSObject, ObservableObject {
    private var current = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private var onChange: ((NSFont) -> Void)?

    /// Показать панель с текущим шрифтом; `onChange` вызывается на каждый выбор пользователя.
    func present(current: NSFont, onChange: @escaping (NSFont) -> Void) {
        self.current = current
        self.onChange = onChange
        let fm = NSFontManager.shared
        fm.target = self
        fm.setSelectedFont(current, isMultiple: false)
        fm.orderFrontFontPanel(self)
    }

    /// Стандартное звено цепочки: панель шлёт changeFont выбранному target.
    @objc func changeFont(_ sender: NSFontManager?) {
        guard let sender else { return }
        let newFont = sender.convert(current)
        current = newFont
        onChange?(newFont)
    }

    /// Нам нужны только семейство, начертание и размер — без подчёркиваний/теней/цвета.
    @objc func validModesForFontPanel(_ fontPanel: NSFontPanel) -> NSFontPanel.ModeMask {
        [.collection, .face, .size]
    }
}
