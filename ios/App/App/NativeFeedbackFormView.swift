import UIKit

/// A real native floating form card, rendered with iOS 26's genuine
/// Liquid Glass material (`UIGlassEffect`), mirroring the web app's
/// feedback form (openFeedbackForm() in index.html): name/email text
/// fields, a multi-line message field with a 500-character counter, and a
/// Send button that stays disabled until all three are filled in - the
/// one `.overlay` dialog left out of NativeModalView because it needs
/// real native text input instead of a fixed title/body/button.
///
/// Field values are read out only when Send is tapped (`onSend`); nothing
/// is sent back to JS as the user types, matching how the HTML version
/// only touches its fields' values on submit.
///
/// REQUIRES BUILDING WITH THE iOS 26 SDK (Xcode 26+) - see
/// NativeToolsFabView's header comment for why; the same applies here.
final class NativeFeedbackFormView: UIView {
    var onSend: ((_ name: String, _ email: String, _ message: String) -> Void)?
    var onDismiss: (() -> Void)?

    private let maxMessageLength = 500
    private let goldColor = UIColor(red: 0.831, green: 0.686, blue: 0.373, alpha: 1)
    private let fieldBackground = UIColor(white: 1, alpha: 0.08)

    private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private var card: UIView?
    private var scrollView: UIScrollView?

    private let nameField = UITextField()
    private let emailField = UITextField()
    private let messageView = UITextView()
    private let messagePlaceholderLabel = UILabel()
    private let countLabel = UILabel()
    private let sendButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBackdrop()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func setupBackdrop() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.alpha = 0
        addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapBackdrop))
        backdrop.addGestureRecognizer(tap)
    }

    @objc private func tapBackdrop() { dismiss() }

    private func glassView(cornerRadius: CGFloat) -> UIView {
        if #available(iOS 26.0, *) {
            let v = UIVisualEffectView(effect: UIGlassEffect())
            v.layer.cornerRadius = cornerRadius
            v.clipsToBounds = true
            return v
        } else {
            let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            v.layer.cornerRadius = cornerRadius
            v.clipsToBounds = true
            return v
        }
    }

    private var nameFieldHeightSet = false
    private var emailFieldHeightSet = false

    /// Configures a persistent field (`nameField`/`emailField`) in place
    /// for the current presentation, rather than building a throwaway
    /// field and copying its properties over - this is simpler and avoids
    /// losing constraints that aren't plain property copies. `heightSet`
    /// is an inout flag (backed by `nameFieldHeightSet`/
    /// `emailFieldHeightSet`) so the 44pt height constraint is added once
    /// per field rather than re-added (and left stacking harmlessly but
    /// messily) on every re-presentation of the form.
    private func styleTextField(_ f: UITextField, placeholder: String, isRTL: Bool, heightSet: inout Bool) {
        f.translatesAutoresizingMaskIntoConstraints = false
        f.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.4)])
        f.text = ""
        f.textColor = UIColor(white: 0.95, alpha: 1)
        f.backgroundColor = fieldBackground
        f.layer.cornerRadius = 12
        f.textAlignment = isRTL ? .right : .left
        f.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 10))
        f.leftView = padding
        f.leftViewMode = .always
        f.rightView = padding
        f.rightViewMode = .always
        if !heightSet {
            f.heightAnchor.constraint(equalToConstant: 44).isActive = true
            heightSet = true
        }
    }

    /// `isRTL` drives field text alignment and the close button's corner,
    /// matching the HTML form's own direction-aware layout.
    func present(title: String, body: String, namePlaceholder: String, emailPlaceholder: String,
                 messagePlaceholder: String, sendButtonText: String, isRTL: Bool) {
        card?.removeFromSuperview()

        let cardView = glassView(cornerRadius: 28)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        addSubview(cardView)
        card = cardView
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: 40),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -40),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            cardView.heightAnchor.constraint(lessThanOrEqualToConstant: 560),
        ])

        let contentView: UIView = (cardView as? UIVisualEffectView)?.contentView ?? cardView

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor(white: 0.6, alpha: 1)
        closeButton.accessibilityLabel = isRTL ? "סגור" : "Close"
        closeButton.addTarget(self, action: #selector(tapBackdrop), for: .touchUpInside)
        contentView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            isRTL
                ? closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14)
                : closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        contentView.addSubview(scroll)
        scrollView = scroll
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -48),
        ])

        let iconView = UIImageView(image: UIImage(systemName: "wrench.and.screwdriver.fill"))
        iconView.tintColor = goldColor
        iconView.contentMode = .scaleAspectFit
        iconView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        stack.addArrangedSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = goldColor
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = UIColor(white: 0.85, alpha: 1)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        stack.addArrangedSubview(bodyLabel)

        nameField.removeFromSuperview()
        emailField.removeFromSuperview()
        styleTextField(nameField, placeholder: namePlaceholder, isRTL: isRTL, heightSet: &nameFieldHeightSet)
        styleTextField(emailField, placeholder: emailPlaceholder, isRTL: isRTL, heightSet: &emailFieldHeightSet)
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        [nameField, emailField].forEach {
            $0.removeTarget(self, action: #selector(updateSendEnabled), for: .editingChanged)
            $0.addTarget(self, action: #selector(updateSendEnabled), for: .editingChanged)
        }
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(emailField)

        let messageContainer = UIView()
        messageContainer.translatesAutoresizingMaskIntoConstraints = false
        messageContainer.backgroundColor = fieldBackground
        messageContainer.layer.cornerRadius = 12
        messageContainer.heightAnchor.constraint(equalToConstant: 100).isActive = true

        messageView.removeFromSuperview()
        messageView.translatesAutoresizingMaskIntoConstraints = false
        messageView.backgroundColor = .clear
        messageView.textColor = UIColor(white: 0.95, alpha: 1)
        messageView.font = .systemFont(ofSize: 15)
        messageView.textAlignment = isRTL ? .right : .left
        messageView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        messageView.delegate = self
        messageView.text = ""
        messageContainer.addSubview(messageView)

        messagePlaceholderLabel.removeFromSuperview()
        messagePlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        messagePlaceholderLabel.text = messagePlaceholder
        messagePlaceholderLabel.textColor = UIColor(white: 1, alpha: 0.4)
        messagePlaceholderLabel.font = .systemFont(ofSize: 15)
        messagePlaceholderLabel.textAlignment = isRTL ? .right : .left
        // textViewDidChange() only fires for user edits, not the
        // programmatic `messageView.text = ""` reset above, so the
        // placeholder's visibility is set explicitly here for a fresh
        // presentation rather than carrying over a stale hidden state.
        messagePlaceholderLabel.isHidden = false
        messageContainer.addSubview(messagePlaceholderLabel)

        NSLayoutConstraint.activate([
            messageView.topAnchor.constraint(equalTo: messageContainer.topAnchor),
            messageView.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor),
            messageView.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor),
            messageView.bottomAnchor.constraint(equalTo: messageContainer.bottomAnchor),
            messagePlaceholderLabel.topAnchor.constraint(equalTo: messageContainer.topAnchor, constant: 10),
            messagePlaceholderLabel.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor, constant: 12),
            messagePlaceholderLabel.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor, constant: -12),
        ])
        stack.addArrangedSubview(messageContainer)

        countLabel.text = "0/\(maxMessageLength)"
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = UIColor(white: 1, alpha: 0.4)
        countLabel.textAlignment = isRTL ? .left : .right
        stack.addArrangedSubview(countLabel)

        sendButton.removeFromSuperview()
        sendButton.setTitle(sendButtonText, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        sendButton.setTitleColor(.black, for: .normal)
        sendButton.setTitleColor(UIColor(white: 0.3, alpha: 1), for: .disabled)
        sendButton.backgroundColor = goldColor
        sendButton.layer.cornerRadius = 22
        sendButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        sendButton.isEnabled = false
        sendButton.alpha = 0.5
        sendButton.removeTarget(self, action: #selector(tapSend), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(tapSend), for: .touchUpInside)
        stack.addArrangedSubview(sendButton)

        isHidden = false
        UIView.animate(withDuration: ReduceMotion.duration(0.25)) {
            self.backdrop.alpha = 1
            cardView.alpha = 1
            cardView.transform = .identity
        }
    }

    @objc private func updateSendEnabled() {
        let filled = !(nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(emailField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !messageView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = filled
        sendButton.alpha = filled ? 1 : 0.5
    }

    @objc private func tapSend() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSend?(nameField.text ?? "", emailField.text ?? "", messageView.text ?? "")
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let scroll = scrollView,
              let userInfo = note.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        else { return }
        let isShowing = note.name == UIResponder.keyboardWillShowNotification
        let overlap = isShowing ? max(0, bounds.maxY - convert(endFrame, from: nil).minY) : 0
        UIView.animate(withDuration: duration) {
            scroll.contentInset.bottom = overlap
            scroll.verticalScrollIndicatorInsets.bottom = overlap
        }
    }

    func dismiss() {
        [nameField, emailField, messageView].forEach { $0.resignFirstResponder() }
        guard let cardView = card else { isHidden = true; return }
        UIView.animate(
            withDuration: ReduceMotion.duration(0.2),
            animations: {
                self.backdrop.alpha = 0
                cardView.alpha = 0
                cardView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            },
            completion: { [weak self] _ in
                cardView.removeFromSuperview()
                self?.card = nil
                self?.isHidden = true
                self?.onDismiss?()
            }
        )
    }
}

extension NativeFeedbackFormView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        messagePlaceholderLabel.isHidden = !textView.text.isEmpty
        countLabel.text = "\(textView.text.count)/\(maxMessageLength)"
        updateSendEnabled()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let newLength = textView.text.count - range.length + text.count
        return newLength <= maxMessageLength
    }
}
