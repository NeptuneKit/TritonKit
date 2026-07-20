import SwiftUI
import UIKit

@main
struct TritonKitTestFixtureApp: App {
    @StateObject private var model = FixtureModel()

    var body: some Scene {
        WindowGroup {
            FixtureRootView(model: model)
                .onAppear { model.autoConnect() }
        }
    }
}

enum FixtureScreen: String {
    case login
    case home
    case settings
    case delayed
    case dynamicList
    case error
}

@MainActor
final class FixtureModel: ObservableObject {
    @Published var screen: FixtureScreen = .login
    @Published var status = "Disconnected"
    @Published var host = Bundle.main.tritonKitDefaultHost
    @Published var port = "19421"
    @Published var delayedLoaded = false
    @Published var alertPresented = false

    #if DEBUG
    private let runtime = TritonKitFixtureDebugBootstrap()
    #endif

    init() {
        #if DEBUG
        runtime.onStatusChange = { [weak self] status in
            Task { @MainActor in self?.status = status }
        }
        #endif
    }

    func autoConnect() {
        #if DEBUG
        writeAppPullSentinel()
        #endif
        connect()
    }

    #if DEBUG
    private func writeAppPullSentinel() {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let directory = applicationSupport.appendingPathComponent("TritonKitFixture", isDirectory: true)
        let file = directory.appendingPathComponent("app-pull-sentinel.json")
        let payload: [String: Any] = [
            "issue": 153,
            "kind": "triton.app-pull.fixture",
            "pass": true,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
    #endif

    func connect() {
        guard let portNumber = UInt16(port) else {
            status = "Invalid Port"
            return
        }

        #if DEBUG
        runtime.connect(host: host, port: portNumber)
        #else
        status = "Disabled"
        #endif
    }

    func show(_ next: FixtureScreen) {
        screen = next
        if next == .delayed {
            delayedLoaded = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard self.screen == .delayed else { return }
                self.delayedLoaded = true
            }
        }
    }
}

private extension Bundle {
    var tritonKitDefaultHost: String {
        let value = object(forInfoDictionaryKey: "TritonKitDefaultHost") as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed == "$(TRITONKIT_DEFAULT_HOST)" {
            return "127.0.0.1"
        }
        return trimmed
    }
}

struct FixtureRootView: View {
    @ObservedObject var model: FixtureModel

    var body: some View {
        FixtureUIKitPanel(status: model.status)
            .ignoresSafeArea()
        .accessibilityIdentifier("fixture.root")
    }
}

struct FixtureUIKitPanel: UIViewRepresentable {
    let status: String

    func makeUIView(context: Context) -> FixtureUIKitView {
        FixtureUIKitView()
    }

    func updateUIView(_ uiView: FixtureUIKitView, context: Context) {
        uiView.updateStatus(status)
    }
}

final class FixtureUIKitView: UIView {
    private let statusLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stack = UIStackView()
    private var screen: FixtureScreen = .login

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        showLogin()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
        showLogin()
    }

    func updateStatus(_ status: String) {
        statusLabel.text = "Fixture Runtime: \(status)"
        statusLabel.accessibilityLabel = statusLabel.text
    }

    private func configure() {
        backgroundColor = .systemBackground
        accessibilityIdentifier = "fixture.root.uikit"

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        statusLabel.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.isAccessibilityElement = true
        statusLabel.accessibilityIdentifier = "fixture.runtime.status"

        titleLabel.font = .systemFont(ofSize: 42, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.isAccessibilityElement = true

        subtitleLabel.font = .systemFont(ofSize: 22, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isAccessibilityElement = true

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 64),
        ])
    }

    private func reset(title: String, titleID: String, subtitle: String? = nil, subtitleID: String? = nil) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        stack.addArrangedSubview(statusLabel)

        titleLabel.text = title
        titleLabel.accessibilityLabel = title
        titleLabel.accessibilityIdentifier = titleID
        stack.addArrangedSubview(titleLabel)

        if let subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.accessibilityLabel = subtitle
            subtitleLabel.accessibilityIdentifier = subtitleID
            stack.addArrangedSubview(subtitleLabel)
        }
    }

    private func addButton(_ title: String, identifier: String, action: Selector) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        button.accessibilityIdentifier = identifier
        button.accessibilityLabel = title
        button.addTarget(self, action: action, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }

    private func addListItem(_ title: String, identifier: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 20, weight: .regular)
        label.textAlignment = .center
        label.isAccessibilityElement = true
        label.accessibilityLabel = title
        label.accessibilityIdentifier = identifier
        stack.addArrangedSubview(label)
    }

    @objc private func showLogin() {
        screen = .login
        reset(
            title: "Fixture Login",
            titleID: "fixture.login.title",
            subtitle: "Fixture Login Ready",
            subtitleID: "fixture.login.ready"
        )
        addButton("Go Home", identifier: "fixture.login.goHome", action: #selector(showHome))
    }

    @objc private func showHome() {
        screen = .home
        reset(title: "Fixture Home", titleID: "fixture.home.title")
        addButton("Open Settings", identifier: "fixture.home.openSettings", action: #selector(showSettings))
        addButton("Open Delayed Loading", identifier: "fixture.home.openDelayed", action: #selector(showDelayed))
        addButton("Open Dynamic List", identifier: "fixture.home.openDynamicList", action: #selector(showDynamicList))
        addButton("Open Error State", identifier: "fixture.home.openError", action: #selector(showError))
        addButton("Open Fixture Alert", identifier: "fixture.home.openAlert", action: #selector(showAlert))
        addButton("Back to Login", identifier: "fixture.home.backLogin", action: #selector(showLogin))
    }

    @objc private func showSettings() {
        screen = .settings
        reset(
            title: "Fixture Settings",
            titleID: "fixture.settings.title",
            subtitle: "Fixture Notifications",
            subtitleID: "fixture.settings.notifications"
        )
        addButton("Back Home", identifier: "fixture.settings.backHome", action: #selector(showHome))
    }

    @objc private func showDelayed() {
        screen = .delayed
        reset(
            title: "Fixture Delayed Loading",
            titleID: "fixture.delayed.title",
            subtitle: "Fixture Loading",
            subtitleID: "fixture.delayed.loading"
        )
        addButton("Back Home", identifier: "fixture.delayed.backHome", action: #selector(showHome))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.screen == .delayed else { return }
            self.subtitleLabel.text = "Fixture Loaded"
            self.subtitleLabel.accessibilityLabel = "Fixture Loaded"
            self.subtitleLabel.accessibilityIdentifier = "fixture.delayed.loaded"
        }
    }

    @objc private func showDynamicList() {
        screen = .dynamicList
        reset(title: "Fixture Dynamic List", titleID: "fixture.list.title")
        for item in 1...8 {
            addListItem("Fixture Item \(item)", identifier: "fixture.list.item.\(item)")
        }
        addButton("Back Home", identifier: "fixture.list.backHome", action: #selector(showHome))
    }

    @objc private func showError() {
        screen = .error
        reset(
            title: "Fixture Error State",
            titleID: "fixture.error.title",
            subtitle: "Fixture Error Message",
            subtitleID: "fixture.error.message"
        )
        addButton("Retry Home", identifier: "fixture.error.retryHome", action: #selector(showHome))
    }

    @objc private func showAlert() {
        let alert = UIAlertController(
            title: "Fixture Modal",
            message: "Fixture Modal Message",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Close Fixture Modal", style: .cancel))
        window?.rootViewController?.present(alert, animated: false)
    }
}

struct FixtureStatusView: View {
    let status: String

    var body: some View {
        Text("Fixture Runtime: \(status)")
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("fixture.runtime.status")
    }
}

struct FixtureLoginView: View {
    @ObservedObject var model: FixtureModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Fixture Login")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("fixture.login.title")

            Text("Fixture Login Ready")
                .font(.body)
                .accessibilityIdentifier("fixture.login.ready")

            Button("Go Home") {
                model.show(.home)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("fixture.login.goHome")
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("fixture.login.screen")
    }
}

struct FixtureHomeView: View {
    @ObservedObject var model: FixtureModel

    var body: some View {
        VStack(spacing: 14) {
            Text("Fixture Home")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("fixture.home.title")

            Button("Open Settings") { model.show(.settings) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fixture.home.openSettings")

            Button("Open Delayed Loading") { model.show(.delayed) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("fixture.home.openDelayed")

            Button("Open Dynamic List") { model.show(.dynamicList) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("fixture.home.openDynamicList")

            Button("Open Error State") { model.show(.error) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("fixture.home.openError")

            Button("Open Fixture Alert") { model.alertPresented = true }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("fixture.home.openAlert")

            Button("Back to Login") { model.show(.login) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("fixture.home.backLogin")
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("fixture.home.screen")
        .alert("Fixture Modal", isPresented: $model.alertPresented) {
            Button("Close Fixture Modal", role: .cancel) {}
                .accessibilityIdentifier("fixture.modal.close")
        } message: {
            Text("Fixture Modal Message")
        }
    }
}

struct FixtureSettingsView: View {
    @ObservedObject var model: FixtureModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Fixture Settings")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("fixture.settings.title")

            Toggle("Fixture Notifications", isOn: .constant(true))
                .accessibilityIdentifier("fixture.settings.notifications")

            Button("Back Home") { model.show(.home) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fixture.settings.backHome")
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("fixture.settings.screen")
    }
}

struct FixtureDelayedView: View {
    @ObservedObject var model: FixtureModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Fixture Delayed Loading")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("fixture.delayed.title")

            Text(model.delayedLoaded ? "Fixture Loaded" : "Fixture Loading")
                .font(.title3)
                .accessibilityIdentifier(model.delayedLoaded ? "fixture.delayed.loaded" : "fixture.delayed.loading")

            Button("Back Home") { model.show(.home) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fixture.delayed.backHome")
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("fixture.delayed.screen")
    }
}

struct FixtureDynamicListView: View {
    @ObservedObject var model: FixtureModel
    private let items = Array(1...8)

    var body: some View {
        VStack(spacing: 12) {
            Text("Fixture Dynamic List")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("fixture.list.title")

            List(items, id: \.self) { item in
                Text("Fixture Item \(item)")
                    .accessibilityIdentifier("fixture.list.item.\(item)")
            }
            .frame(height: 260)
            .accessibilityIdentifier("fixture.list.items")

            Button("Back Home") { model.show(.home) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fixture.list.backHome")
        }
        .accessibilityIdentifier("fixture.list.screen")
    }
}

struct FixtureErrorView: View {
    @ObservedObject var model: FixtureModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Fixture Error State")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("fixture.error.title")

            Text("Fixture Error Message")
                .font(.title3)
                .foregroundStyle(.red)
                .accessibilityIdentifier("fixture.error.message")

            Button("Retry Home") { model.show(.home) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fixture.error.retryHome")
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("fixture.error.screen")
    }
}
