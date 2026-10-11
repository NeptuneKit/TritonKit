import UIKit

@main
final class AcceptanceApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = GridController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class GridController: UIViewController {
    private var buttons: [UIButton] = []
    private let grid = UIStackView()
    private let detail = UILabel()
    private let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        grid.axis = .vertical
        grid.spacing = 40
        grid.translatesAutoresizingMaskIntoConstraints = false
        for row in 0..<3 {
            let rowView = UIStackView()
            rowView.spacing = 50
            for column in 0..<3 {
                let index = row * 3 + column
                let button = UIButton(type: .system)
                button.setTitle("Cell \(index)", for: .normal)
                button.accessibilityIdentifier = "cell-\(index)"
                button.tag = index
                button.widthAnchor.constraint(equalToConstant: 230).isActive = true
                button.heightAnchor.constraint(equalToConstant: 110).isActive = true
                button.addTarget(self, action: #selector(selectCell(_:)), for: .primaryActionTriggered)
                rowView.addArrangedSubview(button)
                buttons.append(button)
            }
            grid.addArrangedSubview(rowView)
        }
        view.addSubview(grid)
        status.text = "Grid"
        status.textColor = .white
        status.accessibilityIdentifier = "screen-state"
        status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status)
        detail.textColor = .white
        detail.font = .systemFont(ofSize: 60)
        detail.text = "Detail"
        detail.accessibilityIdentifier = "detail-screen"
        detail.isHidden = true
        detail.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detail)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.topAnchor.constraint(equalTo: view.topAnchor, constant: 70),
            detail.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detail.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { buttons.isEmpty ? [] : [buttons[4]] }

    @objc private func selectCell(_ sender: UIButton) {
        grid.isHidden = true
        detail.isHidden = false
        status.text = "Detail \(sender.tag)"
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }), !detail.isHidden {
            detail.isHidden = true
            grid.isHidden = false
            status.text = "Grid"
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
            return
        }
        super.pressesEnded(presses, with: event)
    }
}
