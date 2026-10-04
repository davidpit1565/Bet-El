import UIKit

/// A real native floating modal card, rendered with iOS 26's genuine
/// Liquid Glass material (`UIGlassEffect`) - not a CSS `backdrop-filter`
/// approximation - mirroring the web app's `.overlay`/`.modal` HTML
/// dialogs (icon, title, body, a primary gold button, a close X, and
/// tap-outside-to-dismiss).
///
/// Covers the "Rate Us" modal and the celebration modal (openRateModal()
/// and celebrate() in index.html) - see NativeModalBridge's header
/// comment for why the feedback form's text inputs are left as HTML for
/// now rather than ported blind.
///
/// The backdrop is a real native blur (UIBlurEffect/UIGlassEffect), not a
/// solid dim, matching the HTML `.overlay`'s own `backdrop-filter:
/// blur(6px)` - this matters for the celebration modal specifically,
/// which always shows over a full-screen HTML confetti burst (see
/// confetti() in index.html): a blurred backdrop lets it stay visible
/// (dimmed and blurred) behind the card, the same as the CSS version,
/// rather than a native celebration modal having to hide it.
///
/// REQUIRES BUILDING WITH THE iOS 26 SDK (Xcode 26+) - see
/// NativeToolsFabView's header comment for why; the same applies here.
final class NativeModalView: UIView {
    var onPrimary: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let goldColor = UIColor(red: 0.831, green: 0.686, blue: 0.373, alpha: 1)
    private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private var card: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBackdrop()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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

    /// `iconSymbol` is an SF Symbol name (e.g. "star.fill"). `isRTL`
    /// mirrors the close button's corner, matching the HTML modal's
    /// `.close-x` placement (top trailing in reading order).
    func present(title: String, body: String, buttonText: String, iconSymbol: String, isRTL: Bool) {
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
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -28),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
        ])

        let contentView: UIView = (cardView as? UIVisualEffectView)?.contentView ?? cardView

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor(white: 0.6, alpha: 1)
        closeButton.addTarget(self, action: #selector(tapBackdrop), for: .touchUpInside)
        contentView.addSubview(closeButton)

        let iconView = UIImageView(image: UIImage(systemName: iconSymbol))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = goldColor
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = goldColor
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentView.addSubview(titleLabel)

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = body
        bodyLabel.font = .systemFont(ofSize: 15)
        bodyLabel.textColor = UIColor(white: 0.85, alpha: 1)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        contentView.addSubview(bodyLabel)

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(buttonText, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = goldColor
        button.layer.cornerRadius = 22
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
        button.addTarget(self, action: #selector(tapPrimary), for: .touchUpInside)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            isRTL
                ? closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14)
                : closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 36),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            bodyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            bodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            button.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 22),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28),
        ])

        isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.backdrop.alpha = 1
            cardView.alpha = 1
            cardView.transform = .identity
        }
    }

    @objc private func tapPrimary() { onPrimary?() }

    func dismiss() {
        guard let cardView = card else { isHidden = true; return }
        UIView.animate(
            withDuration: 0.2,
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
