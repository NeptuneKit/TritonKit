import UIKit
import WebKit

@main final class BatchApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Batch", sessionRole: session.role)
        configuration.delegateClass = BatchScene.self
        return configuration
    }
}

final class BatchScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = BatchViewController()
        window.makeKeyAndVisible(); self.window = window
    }
}

final class BatchViewController: UIViewController {
    let counter = UILabel()
    var count = 0
    #if DEBUG
    let runtime = TritonKitFixtureDebugBootstrap()
    #endif
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)])
        counter.text = "HID taps: 0"; counter.accessibilityIdentifier = "batch-counter"
        stack.addArrangedSubview(counter)
        let button = UIButton(type: .system); button.setTitle("Physical touch probe", for: .normal)
        button.accessibilityIdentifier = "batch-tap"; button.heightAnchor.constraint(equalToConstant: 64).isActive = true
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside); stack.addArrangedSubview(button)
        let pref = UILabel(); pref.text = "Preference: " + (UserDefaults.standard.object(forKey: "BatchTemporary").map { String(describing: $0) } ?? "absent")
        stack.addArrangedSubview(pref)
        let scroll = UIScrollView(); scroll.heightAnchor.constraint(equalToConstant: 90).isActive = true
        let items = UIStackView(); items.axis = .horizontal; items.spacing = 10
        for i in 1...20 { let label = UILabel(); label.text = "item\(i)"; label.widthAnchor.constraint(equalToConstant: 90).isActive = true; items.addArrangedSubview(label) }
        items.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(items)
        NSLayoutConstraint.activate([items.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), items.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), items.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), items.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), items.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)])
        stack.addArrangedSubview(scroll)
        let web = WKWebView(); stack.addArrangedSubview(web)
        web.loadHTMLString("<html data-triton-form-input='1'><head><title>BatchSnapshot237</title><meta name='viewport' content='width=device-width'></head><body><h2>Snapshot ready</h2><input name='plain' value='original'><textarea id='multi'>two lines</textarea><script>var e=document.createElement('input');e.name='quote\\\"and\\\\slash';e.value='special';document.body.appendChild(e);</script></body></html>", baseURL: nil)
        #if DEBUG
        runtime.connect(host: "127.0.0.1", port: 19422)
        #endif
    }
    @objc func tapped() { count += 1; counter.text = "HID taps: \(count)" }
}
