import AppKit

final class CheckboxMenuItemView: NSView {
    private enum Metrics {
        static let width: CGFloat = 280
        static let height: CGFloat = 24
        static let leadingPadding: CGFloat = 14
        static let childIndent: CGFloat = 18
        static let trailingPadding: CGFloat = 8
    }

    private let checkbox: NSButton
    var onToggle: (() -> Void)?

    init(title: String, isOn: Bool, isEnabled: Bool = true, isChild: Bool = false) {
        self.checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: Metrics.width, height: Metrics.height))

        checkbox.target = self
        checkbox.action = #selector(toggle)
        checkbox.state = isOn ? .on : .off
        checkbox.isEnabled = isEnabled
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkbox)

        let leading = Metrics.leadingPadding + (isChild ? Metrics.childIndent : 0)
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metrics.trailingPadding),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(title: String, isOn: Bool, isEnabled: Bool) {
        checkbox.title = title
        checkbox.state = isOn ? .on : .off
        checkbox.isEnabled = isEnabled
    }

    /// Reached when the mouse is released over the row without the checkbox
    /// having tracked the press — e.g. after long-pressing the status item and
    /// dragging onto this row. A normal click on the checkbox is handled by the
    /// checkbox's own tracking and never arrives here.
    override func mouseUp(with event: NSEvent) {
        guard checkbox.isEnabled else { return }
        toggle()
    }

    @objc
    private func toggle() {
        onToggle?()
    }
}
