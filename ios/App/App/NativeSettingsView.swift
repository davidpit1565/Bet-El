import UIKit

/// One row in the native Settings table - see NativeSettingsBridge's
/// header comment for the full spec this is parsed from.
struct NativeSettingsRow {
    let id: String
    let type: String // toggle, stepper, select, segmented, button, disclosure, link
    let title: String
    let subtitle: String
    let boolValue: Bool
    let stringValue: String
    let options: [(value: String, label: String)]
    let url: String?
}

struct NativeSettingsSection {
    let header: String
    let rows: [NativeSettingsRow]
}

/// A real native `UITableView` (`.insetGrouped`, the genuine system
/// Settings-app look, not a CSS approximation of one) mirroring the web
/// app's own Settings screen - see NativeSettingsBridge's header comment
/// in index.html (`nativeSettingsSpec()`) for why most rows relay to the
/// already-rendered HTML control underneath rather than duplicating its
/// logic here, and why a few rows are deliberately left as plain
/// "disclosure" taps back to that HTML screen instead.
final class NativeSettingsView: UIView {
    /// (rowId, value-as-string-or-nil) - value is set for stepper
    /// ("Minus"/"Plus" suffix folded into the id itself, see
    /// `relayAction`), select and segmented rows; nil for a plain
    /// toggle/button/disclosure tap (those relay by id alone, and the web
    /// side just clicks the matching real HTML control either way).
    var onAction: ((String, String?) -> Void)?

    private let goldColor = UIColor(red: 0.831, green: 0.686, blue: 0.373, alpha: 1)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [NativeSettingsSection] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTable()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tintColor = goldColor
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Reloads in place - called on every `configure()` while already
    /// visible too (e.g. right after a toggle flips), so the native table
    /// always mirrors whatever the web side just computed, the same way
    /// NativeTabBar/NativeToolsFab re-push their whole state on any change
    /// rather than patching a single field.
    func configure(sections: [NativeSettingsSection], isDark: Bool) {
        self.sections = sections
        overrideUserInterfaceStyle = isDark ? .dark : .light
        tableView.reloadData()
    }

    private func relayAction(_ id: String, value: String? = nil) {
        onAction?(id, value)
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        relayAction(rowId(forTag: sender.tag))
    }

    @objc private func stepperMinusTapped(_ sender: UIButton) {
        relayAction(rowId(forTag: sender.tag) + "Minus")
    }

    @objc private func stepperPlusTapped(_ sender: UIButton) {
        relayAction(rowId(forTag: sender.tag) + "Plus")
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let row = row(forTag: sender.tag)
        guard sender.selectedSegmentIndex >= 0, sender.selectedSegmentIndex < row.options.count else { return }
        relayAction(row.id, value: row.options[sender.selectedSegmentIndex].value)
    }

    // MARK: - Row lookup by a flat tag (section*1000 + row), since
    // UIKit controls only carry a single Int `tag`, not an IndexPath.

    private func row(forTag tag: Int) -> NativeSettingsRow {
        sections[tag / 1000].rows[tag % 1000]
    }

    private func rowId(forTag tag: Int) -> String { row(forTag: tag).id }

    private func tag(for indexPath: IndexPath) -> Int { indexPath.section * 1000 + indexPath.row }
}

extension NativeSettingsView: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let header = sections[section].header
        return header.isEmpty ? nil : header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = row.title
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = row.subtitle
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        cell.accessoryType = .none
        cell.accessoryView = nil

        let tagValue = tag(for: indexPath)

        switch row.type {
        case "toggle":
            let sw = UISwitch()
            sw.isOn = row.boolValue
            sw.tag = tagValue
            sw.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
            cell.accessoryView = sw

        case "stepper":
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 10
            stack.alignment = .center

            let minus = UIButton(type: .system)
            minus.setTitle("−", for: .normal)
            minus.tag = tagValue
            minus.addTarget(self, action: #selector(stepperMinusTapped(_:)), for: .touchUpInside)

            let valueLabel = UILabel()
            valueLabel.text = row.stringValue
            valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
            valueLabel.textAlignment = .center
            valueLabel.widthAnchor.constraint(equalToConstant: 46).isActive = true

            let plus = UIButton(type: .system)
            plus.setTitle("+", for: .normal)
            plus.tag = tagValue
            plus.addTarget(self, action: #selector(stepperPlusTapped(_:)), for: .touchUpInside)

            stack.addArrangedSubview(minus)
            stack.addArrangedSubview(valueLabel)
            stack.addArrangedSubview(plus)
            stack.sizeToFit()
            cell.accessoryView = stack
            cell.detailTextLabel?.text = row.subtitle

        case "segmented":
            let seg = UISegmentedControl(items: row.options.map { $0.label })
            if let idx = row.options.firstIndex(where: { $0.value == row.stringValue }) {
                seg.selectedSegmentIndex = idx
            }
            seg.tag = tagValue
            seg.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
            // A fixed width (rather than intrinsic sizing) keeps multi-option
            // segmented controls from being squeezed unreadably narrow next
            // to a long title/subtitle on smaller screens.
            seg.widthAnchor.constraint(equalToConstant: 180).isActive = true
            cell.accessoryView = seg
            cell.detailTextLabel?.text = row.subtitle

        case "select":
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            if let label = row.options.first(where: { $0.value == row.stringValue })?.label {
                cell.detailTextLabel?.text = label
            }

        case "link", "disclosure", "button":
            cell.accessoryType = row.type == "button" ? .none : .disclosureIndicator
            cell.selectionStyle = .default

        default:
            break
        }

        return cell
    }
}

extension NativeSettingsView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row.type {
        case "select":
            presentOptionSheet(for: row)
        case "link":
            if let urlString = row.url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        case "button", "disclosure":
            relayAction(row.id)
        default:
            break
        }
    }

    private func presentOptionSheet(for row: NativeSettingsRow) {
        guard let viewController = parentViewController() else { return }
        let sheet = UIAlertController(title: row.title, message: nil, preferredStyle: .actionSheet)
        for option in row.options {
            sheet.addAction(UIAlertAction(title: option.label, style: .default) { [weak self] _ in
                self?.relayAction(row.id, value: option.value)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.bounds
        }
        viewController.present(sheet, animated: true)
    }

    private func parentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}
