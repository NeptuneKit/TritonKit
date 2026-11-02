import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Acceptance", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = AcceptanceSceneDelegate.self
        return configuration
    }
}

final class AcceptanceSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = AcceptanceViewController()
        self.window = window
        window.makeKeyAndVisible()
        #if DEBUG
        AcceptanceRuntime.startIfRequested()
        #endif
    }
}

final class AcceptanceViewController: UIViewController {
    let webView = WKWebView(frame: .zero)
    private(set) var fixtureLoadError: String?

    override func loadView() {
        webView.accessibilityIdentifier = "WebView204ControlledAcceptance"
        webView.inputAssistantItem.leadingBarButtonGroups = []
        webView.inputAssistantItem.trailingBarButtonGroups = []
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFixture()
    }

    @discardableResult
    func reloadFixture() -> String {
        let generation = UUID().uuidString
        do {
            guard let htmlURL = Bundle.main.url(forResource: "fixture", withExtension: "html", subdirectory: "Fixture"),
                  let scriptURL = Bundle.main.url(forResource: "fixture", withExtension: "js", subdirectory: "Fixture") else {
                throw NSError(domain: "ControlledAcceptanceResources", code: 1)
            }
            let template = try String(contentsOf: htmlURL, encoding: .utf8)
            let script = try String(contentsOf: scriptURL, encoding: .utf8)
                .replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
            let html = template.replacingOccurrences(of: "__GENERATION__", with: generation)
                .replacingOccurrences(of: "__BUNDLED_JS__", with: script)
            fixtureLoadError = nil
            webView.loadHTMLString(html, baseURL: URL(string: "https://tritonkit.local/acceptance204"))
        } catch {
            fixtureLoadError = String(describing: error)
        }
        return generation
    }
}
