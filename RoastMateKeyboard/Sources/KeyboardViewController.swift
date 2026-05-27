import UIKit

/// v1.2 keyboard-extension **SPIKE skeleton** — capture-and-handoff only.
///
/// This is intentionally NOT a full keyboard layout (QWERTY / locales /
/// autocorrect = the deferred multi-week scope). It exists to prove the
/// architecture the spike concluded is the only viable one (see
/// `docs/v1.2_KEYBOARD_SPIKE.md`):
///
/// - The keyboard CANNOT generate (≈48 MB extension memory ceiling vs.
///   the on-device Foundation Model) and MUST NOT own network / safety /
///   Pro gating (those live in the app, same rationale as
///   `QuickVentIntent`). So it only *captures* the field text and parks
///   it via `LaunchRouter` for the app to drain on next foreground.
/// - It performs **zero network**. The `RequestsOpenAccess` (Full
///   Access) it declares is required solely to reach the App Group, not
///   to phone home.
final class KeyboardViewController: UIInputViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        EventLedger.shared.recordFeatureUsageKeyboard()
        configureSpikeBar()
    }

    private func configureSpikeBar() {
        let nextKey = makeButton(title: "🌐", action: #selector(advanceToNext))
        let ventKey = makeButton(title: "Vent this → RoastMate",
                                 action: #selector(captureToApp))

        let stack = UIStackView(arrangedSubviews: [nextKey, ventKey])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fill
        nextKey.setContentHuggingPriority(.required, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            view.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = title
        cfg.cornerStyle = .large
        let button = UIButton(configuration: cfg)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func advanceToNext() {
        advanceToNextInputMode()
    }

    /// Capture the surrounding field text and hand it to the app. The
    /// keyboard does not generate, validate, or transmit — `LaunchRouter`
    /// only writes to the shared App Group suite; the app runs the
    /// unchanged SafetyFilter / crisis / cloud-consent gates when it
    /// drains it.
    @objc private func captureToApp() {
        let proxy = textDocumentProxy
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        LaunchRouter.shared.flagCapturedSituation(before + after)
    }
}
