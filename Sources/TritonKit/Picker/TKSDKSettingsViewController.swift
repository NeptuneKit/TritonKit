#if canImport(UIKit)
import UIKit

/// Native settings content. Presentation and the SDK lifecycle belong to the caller.
@MainActor
final class TKSDKSettingsViewController: UITableViewController {
    enum Page { case home, connection, picker, capabilities, app, entry }

    @MainActor
    private final class Model {
        var configuration: TritonKit.PickerConfiguration
        let snapshotProvider: () -> TKSDKSettingsSnapshot
        var snapshot: TKSDKSettingsSnapshot
        let onChange: (Bool, Bool, Bool) -> Void
        let onHide: () -> Void
        var onClose: (() -> Void)?

        init(configuration: TritonKit.PickerConfiguration,
             snapshotProvider: @escaping () -> TKSDKSettingsSnapshot,
             onChange: @escaping (Bool, Bool, Bool) -> Void,
             onHide: @escaping () -> Void) {
            self.configuration = configuration
            self.snapshotProvider = snapshotProvider
            self.snapshot = snapshotProvider()
            self.onChange = onChange
            self.onHide = onHide
        }
    }

    private struct Row {
        let title: String
        let identifier: String
        var value: String? = nil
        var icon: String? = nil
        var destination: Page? = nil
        var toggle: Int? = nil
        var hidesEntry = false
    }

    private struct Section {
        var header: String? = nil
        var footer: String? = nil
        let rows: [Row]
    }

    let page: Page
    private let model: Model
    private var sections: [Section] = []

    var onClose: (() -> Void)? {
        get { model.onClose }
        set { model.onClose = newValue }
    }

    init(page: Page = .home,
         configuration: TritonKit.PickerConfiguration,
         snapshotProvider: @escaping () -> TKSDKSettingsSnapshot,
         onChange: @escaping (Bool, Bool, Bool) -> Void,
         onHide: @escaping () -> Void) {
        self.page = page
        model = Model(configuration: configuration, snapshotProvider: snapshotProvider,
                      onChange: onChange, onHide: onHide)
        super.init(style: .insetGrouped)
    }

    private init(page: Page, model: Model) {
        self.page = page
        self.model = model
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = pageTitle
        tableView.accessibilityIdentifier = "triton.settings.panel"
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 48
        navigationItem.largeTitleDisplayMode = .never
        let close = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closePanel))
        close.accessibilityIdentifier = "triton.settings.close"
        close.accessibilityLabel = "关闭面板"
        navigationItem.rightBarButtonItem = close
        let back = UIBarButtonItem(title: "返回", style: .plain, target: nil, action: nil)
        back.accessibilityIdentifier = "triton.settings.back"
        navigationItem.backBarButtonItem = back
        sections = makeSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshSnapshot()
    }

    func update(_ configuration: TritonKit.PickerConfiguration) {
        model.configuration = configuration
        refreshLoadedPages()
    }

    /// Updates read-only values in place rather than resetting the page or scroll position.
    func refreshSnapshot() {
        model.snapshot = model.snapshotProvider()
        refreshLoadedPages()
    }

    private func refreshLoadedPages() {
        let pages = navigationController?.viewControllers.compactMap { $0 as? TKSDKSettingsViewController } ?? [self]
        for controller in pages where controller.model === model && controller.isViewLoaded {
            controller.refreshRows()
        }
    }

    private func refreshRows() {
        let updated = makeSections()
        let sameStructure = sections.map { $0.rows.map(\.identifier) } == updated.map { $0.rows.map(\.identifier) }
        sections = updated
        if sameStructure {
            for indexPath in tableView.indexPathsForVisibleRows ?? [] {
                if let cell = tableView.cellForRow(at: indexPath) {
                    configure(cell, row: sections[indexPath.section].rows[indexPath.row])
                }
            }
        } else {
            let offset = tableView.contentOffset
            UIView.performWithoutAnimation {
                tableView.reloadData()
                tableView.layoutIfNeeded()
                tableView.setContentOffset(offset, animated: false)
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settings")
            ?? UITableViewCell(style: .value1, reuseIdentifier: "settings")
        configure(cell, row: sections[indexPath.section].rows[indexPath.row])
        return cell
    }

    private func configure(_ cell: UITableViewCell, row: Row) {
        cell.accessibilityIdentifier = "triton.settings.\(row.identifier)"
        cell.textLabel?.text = row.title
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.textColor = row.hidesEntry ? .systemRed : .label
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.accessibilityIdentifier = row.identifier == "connection" || row.identifier == "connectionState"
            ? "triton.settings.connectionStatus" : nil
        cell.imageView?.image = row.icon.flatMap { UIImage(systemName: $0) }
        cell.imageView?.tintColor = .secondaryLabel
        let existingToggle = cell.accessoryView as? UISwitch
        if row.toggle == nil { cell.accessoryView = nil }
        cell.accessoryType = row.destination == nil ? .none : .disclosureIndicator
        cell.selectionStyle = row.destination != nil || row.hidesEntry ? .default : .none
        if let toggleIndex = row.toggle {
            let toggle = existingToggle ?? UISwitch()
            toggle.tag = toggleIndex
            toggle.accessibilityIdentifier = "triton.settings.\(row.identifier)"
            toggle.accessibilityLabel = row.title
            switch toggleIndex {
            case 0: toggle.isOn = model.configuration.magnifierEnabled
            case 1: toggle.isOn = model.configuration.guidesEnabled
            default: toggle.isOn = model.configuration.feedbackEnabled
            }
            if existingToggle == nil {
                toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
            }
            cell.accessoryView = toggle
            // The native switch remains separately accessible with its on/off value.
            cell.isAccessibilityElement = false
        } else {
            // Keep the connection value as an independently identifiable UILabel.
            cell.isAccessibilityElement = row.identifier != "connection" && row.identifier != "connectionState"
            cell.accessibilityLabel = row.title
            cell.accessibilityValue = row.value
            cell.accessibilityTraits = row.destination != nil || row.hidesEntry ? [.button] : [.staticText]
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        if let destination = row.destination {
            navigationController?.pushViewController(TKSDKSettingsViewController(page: destination, model: model), animated: true)
        } else if row.hidesEntry {
            confirmHide()
        }
    }

    @objc private func toggleChanged(_ toggle: UISwitch) {
        switch toggle.tag {
        case 0: model.configuration.magnifierEnabled = toggle.isOn
        case 1: model.configuration.guidesEnabled = toggle.isOn
        default: model.configuration.feedbackEnabled = toggle.isOn
        }
        let config = model.configuration
        model.onChange(config.magnifierEnabled, config.guidesEnabled, config.feedbackEnabled)
    }

    @objc private func closePanel() { model.onClose?() }

    private func confirmHide() {
        let alert = UIAlertController(
            title: "隐藏悬浮入口？",
            message: "隐藏后将清除当前标记，SDK 连接保持。需要通过宿主提供的入口重新显示。",
            preferredStyle: .alert
        )
        let cancel = UIAlertAction(title: "取消", style: .cancel)
        cancel.accessibilityIdentifier = "triton.settings.cancelHide"
        let confirm = UIAlertAction(title: "隐藏", style: .destructive) { [weak self] _ in self?.model.onHide() }
        confirm.accessibilityIdentifier = "triton.settings.confirmHide"
        alert.addAction(cancel)
        alert.addAction(confirm)
        present(alert, animated: true)
    }

    private var pageTitle: String {
        switch page {
        case .home: return "TritonKit"
        case .connection: return "连接与会话"
        case .picker: return "控件选择器"
        case .capabilities: return "SDK 功能"
        case .app: return "应用与环境"
        case .entry: return "悬浮入口"
        }
    }

    private func makeSections() -> [Section] {
        let snapshot = model.snapshot
        switch page {
        case .home:
            return [
                Section(rows: [Row(title: "连接与会话", identifier: "connection", value: snapshot.connectionTitle,
                                   icon: "network", destination: .connection)]),
                Section(header: "调试与配置", rows: [
                    Row(title: "控件选择器", identifier: "picker", icon: "viewfinder", destination: .picker),
                    Row(title: "SDK 功能", identifier: "capabilities", icon: "square.grid.2x2", destination: .capabilities),
                ]),
                Section(rows: [
                    Row(title: "应用与环境", identifier: "app", icon: "info.circle", destination: .app),
                    Row(title: "悬浮入口", identifier: "entry", icon: "circle.dashed", destination: .entry),
                ]),
            ]
        case .connection:
            return [Section(footer: "连接由宿主配置。查看此页不会断开或重启 SDK。", rows: [
                Row(title: "连接状态", identifier: "connectionState", value: snapshot.connectionTitle),
                Row(title: "服务地址", identifier: "endpoint", value: snapshot.endpoint),
                Row(title: "自动重连", identifier: "reconnect", value: snapshot.reconnectTitle),
            ])]
        case .picker:
            return [Section(footer: "拖动圆球选择控件，松手后使用方向罗盘。设置仅对本次运行生效。", rows: [
                Row(title: "拖选放大镜", identifier: "magnifier", toggle: 0),
                Row(title: "密集控件辅助框", identifier: "guides", toggle: 1),
                Row(title: "选择触感", identifier: "feedback", toggle: 2),
            ])]
        case .capabilities:
            return [Section(header: "宿主配置", footer: "实际可用性取决于平台与当前界面。", rows:
                snapshot.features.enumerated().map { index, feature in
                    Row(title: feature.title, identifier: "feature.\(index)", value: feature.enabled ? "已启用" : "未启用")
                }
            )]
        case .app:
            return [Section(footer: snapshot.app.isEmpty ? "未提供应用信息。" : nil, rows:
                snapshot.app.enumerated().map { index, info in
                    Row(title: info.title, identifier: "appInfo.\(index)", value: info.value)
                }
            )]
        case .entry:
            return [
                Section(rows: [Row(title: "移动入口", identifier: "moveEntry", value: "长按圆球后拖动")]),
                Section(footer: "隐藏后需由宿主提供的入口重新唤回。", rows: [
                    Row(title: "隐藏悬浮入口", identifier: "hide", hidesEntry: true),
                ]),
            ]
        }
    }
}
#endif
