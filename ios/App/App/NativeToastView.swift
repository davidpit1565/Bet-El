import UIKit

/// A real native Liquid Glass toast pill (`UIGlassEffect`), replacing the
/// web app's `.toast` CSS `backdrop-filter` approximation the same way
/// NativeModalView already replaced `.overlay`/`.modal` - see that file's
/// header comment for why a genuine system material beats any CSS
/// approximation of it. Auto-dismisses after a fixed duration, matching
/// `toast()`'s own 2.2s timeout in index.html.
///
/// REQUIRES BUILDING WITH THE iOS 26 SDK (Xcode 26+) - see
/// NativeToolsFabView's header comment for why.
final class NativeToastView: UIView {
    private let goldColor = UIColor(red: 0.831, green: 0.686, blue: 0.373, alpha: 1)
    private var pill: UIView?
    private var hideWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func glassView(cornerRadius: CGFloat) -> UIView {
        if #available(iOS 26.0, *) {
            let v = UIVisualEffectView(effect: UIGlassEffect())
            v.layer.cornerRadius = cornerRadius
            v.clipsToBounds = true
            return v
        } else {
            let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
            v.layer.cornerRadius = cornerRadius
            v.clipsToBounds = true
            return v
        }
    }

    func show(message: String) {
        hideWorkItem?.cancel()
        pill?.removeFromSuperview()

        let pillView = glassView(cornerRadius: 20)
        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.alpha = 0
        pillView.transform = CGAffineTransform(translationX: 0, y: 14)
        addSubview(pillView)
        pill = pillView
        NSLayoutConstraint.activate([
            pillView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pillView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            pillView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
        ])

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.font = .systemFont(ofSize: 14.5, weight: .semibold)
        label.textColor = goldColor
        label.textAlignment = .center
        label.numberOfLines = 2

        let contentView: UIView = (pillView as? UIVisualEffectView)?.contentView ?? pillView
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        isHidden = false
        UIView.animate(withDuration: ReduceMotion.duration(0.22)) {
            pillView.alpha = 1
            pillView.transform = .identity
        }

        let workItem = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
    }

    private func hide() {
        guard let pillView = pill else { isHidden = true; return }
        UIView.animate(
            withDuration: ReduceMotion.duration(0.2),
            animations: {
                pillView.alpha = 0
                pillView.transform = CGAffineTransform(translationX: 0, y: 14)
            },
            completion: { [weak self] _ in
                pillView.removeFromSuperview()
                self?.pill = nil
                self?.isHidden = true
            }
        )
    }
}
