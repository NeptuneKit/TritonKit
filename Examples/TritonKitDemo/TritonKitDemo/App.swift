import SwiftUI
import UIKit
import WebKit

@main
struct TritonKitDemoApp: App {
    @StateObject private var model = DemoModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear { model.autoConnect() }
        }
    }
}

final class DemoModel: ObservableObject {
    @Published var status = "Disconnected"
    @Published var host = "127.0.0.1"
    @Published var port = "19421"
    @Published var log: [String] = []

    #if DEBUG
    private let runtime = TritonKitDebugBootstrap()
    #endif

    init() {
        #if DEBUG
        runtime.onStatusChange = { [weak self] status in
            self?.status = status
        }
        runtime.onLog = { [weak self] message in
            self?.addLog(message)
        }
        #endif
    }

    func autoConnect() {
        connect()
    }

    func connect() {
        guard let portNum = UInt16(port) else {
            addLog("Invalid port: \(port)")
            return
        }

        #if DEBUG
        runtime.connect(host: host, port: portNum)
        #else
        status = "Disabled"
        addLog("TritonKit runtime is DEBUG-only")
        #endif
    }

    func disconnect() {
        #if DEBUG
        runtime.disconnect()
        #else
        status = "Disabled"
        addLog("TritonKit runtime is DEBUG-only")
        #endif
    }

    private func addLog(_ msg: String) {
        let entry = "[\(Date().formatted(.dateTime.hour().minute().second()))] \(msg)"
        DispatchQueue.main.async { self.log.append(entry) }
    }
}

struct ContentView: View {
    @ObservedObject var model: DemoModel

    var body: some View {
        VStack(spacing: 16) {
            Text("TritonKit Demo").font(.largeTitle).bold()

            Text("Status: \(model.status)")
                .foregroundColor(model.status == "Connected" ? .green : .orange)
                .font(.headline)

            HStack {
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder).frame(width: 140)
                TextField("Port", text: $model.port)
                    .textFieldStyle(.roundedBorder).frame(width: 80)
            }

            HStack {
                Button("Connect", action: model.connect)
                Button("Disconnect", action: model.disconnect)
            }

            UIKitSmokePanel()
                .frame(height: 320)

            WebViewSmokePanel()
                .frame(height: 150)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.log.reversed(), id: \.self) { entry in
                        Text(entry).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(.systemGroupedBackground)).cornerRadius(8)
        }
        .padding()
    }
}

struct UIKitSmokePanel: UIViewRepresentable {
    func makeUIView(context: Context) -> UIKitSmokeView {
        UIKitSmokeView()
    }

    func updateUIView(_ uiView: UIKitSmokeView, context: Context) {}
}

struct WebViewSmokePanel: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.accessibilityIdentifier = "WebViewSmokeWebView"
        webView.scrollView.accessibilityIdentifier = "WebViewSmokeScrollView"
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.loadHTMLString(Self.html, baseURL: URL(string: "https://tritonkit.local/smoke"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private static let html = """
    <!doctype html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Triton WebView Smoke</title>
      <style>
        body { margin: 0; font: -apple-system-body; color: #111827; background: #eef6f2; }
        main { padding: 14px; }
        h1 { font-size: 18px; margin: 0 0 8px; }
        p { font-size: 13px; margin: 0 0 10px; color: #475569; }
        button { appearance: none; border: 0; border-radius: 6px; background: #0f766e; color: white; padding: 8px 12px; font-weight: 600; }
        input { border: 1px solid #94a3b8; border-radius: 6px; padding: 7px 8px; width: 140px; margin-left: 8px; }
      </style>
    </head>
    <body>
      <main>
        <h1>Triton WebView Smoke</h1>
        <p id="route">route=/smoke ready=true</p>
        <button id="submit">Submit</button>
        <input id="keyword" aria-label="Keyword" value="triton">
      </main>
      <script>
        window.__tritonBridge = {
          version: 1,
          methods: {
            getRouteState: function() {
              return {
                route: "/smoke",
                title: document.title,
                ready: true
              };
            },
            submitSearch: function(args) {
              var keyword = (args && args.keyword) || "";
              document.getElementById("keyword").value = keyword;
              document.getElementById("route").textContent = "route=/smoke ready=true keyword=" + keyword;
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.triton) {
                window.webkit.messageHandlers.triton.postMessage({
                  type: "event",
                  name: "search.submitted",
                  payload: {
                    keywordLength: keyword.length
                  }
                });
              }
              return {
                ok: true,
                keywordLength: keyword.length
              };
            }
          }
        };
      </script>
    </body>
    </html>
    """
}

final class UIKitSmokeView: UIView {
    private let statusLabel = UILabel()
    private let summaryLabel = UILabel()
    private let textField = UITextField()
    private let textView = UITextView()
    private let modeControl = UISegmentedControl(items: ["Inspect", "Edit", "Audit"])
    private let slider = UISlider()
    private let sliderValueLabel = UILabel()
    private let stepper = UIStepper()
    private let stepperValueLabel = UILabel()
    private let toggle = UISwitch()
    private let carouselScrollView = UIScrollView()
    private var tapCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 8
        accessibilityIdentifier = "ComplexHarnessPanel"

        statusLabel.text = "Complex harness: 0"
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.accessibilityIdentifier = "ComplexHarnessStatus"

        summaryLabel.text = "mode=Inspect progress=50 count=2 switch=off text=-"
        summaryLabel.font = .systemFont(ofSize: 11, weight: .regular)
        summaryLabel.numberOfLines = 2
        summaryLabel.accessibilityIdentifier = "ComplexHarnessSummary"

        modeControl.selectedSegmentIndex = 0
        modeControl.accessibilityIdentifier = "ComplexHarnessMode"
        modeControl.accessibilityLabel = "Mode"
        modeControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0.5
        slider.accessibilityIdentifier = "ComplexHarnessSlider"
        slider.accessibilityLabel = "Progress"
        slider.addTarget(self, action: #selector(controlChanged), for: .valueChanged)

        sliderValueLabel.text = "50%"
        sliderValueLabel.font = .systemFont(ofSize: 12, weight: .medium)
        sliderValueLabel.textAlignment = .right
        sliderValueLabel.accessibilityIdentifier = "ComplexHarnessSliderValue"

        stepper.minimumValue = 0
        stepper.maximumValue = 9
        stepper.stepValue = 1
        stepper.value = 2
        stepper.accessibilityIdentifier = "ComplexHarnessStepper"
        stepper.accessibilityLabel = "Count"
        stepper.addTarget(self, action: #selector(controlChanged), for: .valueChanged)

        stepperValueLabel.text = "2"
        stepperValueLabel.font = .systemFont(ofSize: 12, weight: .medium)
        stepperValueLabel.textAlignment = .center
        stepperValueLabel.accessibilityIdentifier = "ComplexHarnessStepperValue"

        textField.placeholder = "Triton type target"
        textField.borderStyle = .roundedRect
        textField.accessibilityIdentifier = "ComplexHarnessTextField"
        textField.addTarget(self, action: #selector(controlChanged), for: .editingChanged)

        textView.text = "Notes"
        textView.font = .systemFont(ofSize: 13)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.cornerRadius = 6
        textView.accessibilityIdentifier = "ComplexHarnessTextView"

        let primaryButton = UIButton(type: .system)
        primaryButton.setTitle("Primary", for: .normal)
        primaryButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        primaryButton.accessibilityIdentifier = "ComplexHarnessPrimary"

        let secondaryButton = UIButton(type: .system)
        secondaryButton.setTitle("Secondary", for: .normal)
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)
        secondaryButton.accessibilityIdentifier = "ComplexHarnessSecondary"

        toggle.accessibilityIdentifier = "ComplexHarnessSwitch"
        toggle.accessibilityLabel = "Enabled"
        toggle.addTarget(self, action: #selector(controlChanged), for: .valueChanged)

        let topRow = UIStackView(arrangedSubviews: [statusLabel, primaryButton, secondaryButton, toggle])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12

        let sliderRow = UIStackView(arrangedSubviews: [slider, sliderValueLabel])
        sliderRow.axis = .horizontal
        sliderRow.alignment = .center
        sliderRow.spacing = 8
        sliderValueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let stepperRow = UIStackView(arrangedSubviews: [stepperValueLabel, stepper])
        stepperRow.axis = .horizontal
        stepperRow.alignment = .center
        stepperRow.spacing = 12
        stepperValueLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let scrollContent = UIStackView()
        scrollContent.axis = .horizontal
        scrollContent.spacing = 10
        for index in 1...18 {
            let label = PaddedLabel()
            label.text = "item \(index)"
            label.font = .systemFont(ofSize: 12)
            label.textAlignment = .center
            label.backgroundColor = .tertiarySystemGroupedBackground
            label.layer.cornerRadius = 6
            label.clipsToBounds = true
            label.accessibilityIdentifier = "ComplexHarnessCarouselItem\(index)"
            label.widthAnchor.constraint(equalToConstant: 72).isActive = true
            scrollContent.addArrangedSubview(label)
        }

        carouselScrollView.addSubview(scrollContent)
        carouselScrollView.showsHorizontalScrollIndicator = true
        carouselScrollView.accessibilityIdentifier = "ComplexHarnessCarousel"
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: carouselScrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: carouselScrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: carouselScrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: carouselScrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.heightAnchor.constraint(equalTo: carouselScrollView.frameLayoutGuide.heightAnchor)
        ])

        let stack = UIStackView(arrangedSubviews: [
            topRow,
            summaryLabel,
            modeControl,
            sliderRow,
            stepperRow,
            textField,
            textView,
            carouselScrollView
        ])
        stack.axis = .vertical
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        carouselScrollView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        textView.heightAnchor.constraint(equalToConstant: 62).isActive = true
        updateSummary()
    }

    @objc private func buttonTapped() {
        tapCount += 1
        statusLabel.text = "Complex harness: \(tapCount)"
        updateSummary()
    }

    @objc private func secondaryTapped() {
        modeControl.selectedSegmentIndex = (modeControl.selectedSegmentIndex + 1) % modeControl.numberOfSegments
        slider.value = min(1, slider.value + 0.1)
        stepper.value = min(stepper.maximumValue, stepper.value + 1)
        updateSummary()
    }

    @objc private func controlChanged() {
        updateSummary()
    }

    private func updateSummary() {
        let mode = modeControl.titleForSegment(at: modeControl.selectedSegmentIndex) ?? "-"
        let progress = Int(round(slider.value * 100))
        let count = Int(stepper.value)
        let switchState = toggle.isOn ? "on" : "off"
        let text = textField.text?.isEmpty == false ? textField.text! : "-"
        sliderValueLabel.text = "\(progress)%"
        stepperValueLabel.text = "\(count)"
        summaryLabel.text = "mode=\(mode) progress=\(progress) count=\(count) switch=\(switchState) text=\(text)"
    }
}

final class PaddedLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 8, dy: 4))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 16, height: size.height + 8)
    }
}
