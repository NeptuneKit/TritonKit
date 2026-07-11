import AVFoundation
import SwiftUI
#if DEBUG
import TritonKit
#endif
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

enum DemoScenario: String, CaseIterable, Identifiable {
    case overview
    case runtimeBasic
    case nativeControls
    case webViewBasic
    case webViewEdge
    case webViewNavigation
    case camera

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .runtimeBasic:
            return "Runtime"
        case .nativeControls:
            return "Native"
        case .webViewBasic:
            return "Web Basic"
        case .webViewEdge:
            return "Web Edge"
        case .webViewNavigation:
            return "Web Nav"
        case .camera:
            return "Camera"
        }
    }

}

final class DemoModel: ObservableObject {
    @Published var status = "Disconnected"
    @Published var host: String
    @Published var port: String
    @Published var scenario: DemoScenario = .overview
    @Published var log: [String] = []

    #if DEBUG
    private let runtime = TritonKitDebugBootstrap()
    #endif

    init() {
        let endpoint = demoEndpoint()
        host = endpoint.host
        port = String(endpoint.port)
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
        let endpoint = demoEndpoint()
        host = endpoint.host
        port = String(endpoint.port)
        connect(host: endpoint.host, port: endpoint.port)
    }

    func connect() {
        guard let portNum = UInt16(port) else {
            addLog("Invalid port: \(port)")
            return
        }
        connect(host: host, port: portNum)
    }

    private func connect(host: String, port: UInt16) {
        #if DEBUG
        runtime.connect(host: host, port: port)
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

private struct DemoEndpoint {
    let host: String
    let port: UInt16
}

private func demoEndpoint() -> DemoEndpoint {
    #if DEBUG
    let endpoint = TritonKitStartPayload.environment()
    return DemoEndpoint(host: endpoint.host, port: endpoint.port)
    #else
    return DemoEndpoint(host: "127.0.0.1", port: 19421)
    #endif
}

struct ContentView: View {
    @ObservedObject var model: DemoModel

    var body: some View {
        VStack(spacing: 16) {
            Text("TritonKit Demo").font(.largeTitle).bold()

            TimelineView(.animation) { timelineContext in
                let timeString: String = {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss.SSS"
                    return formatter.string(from: timelineContext.date)
                }()
                Text(timeString)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.blue)
                    .bold()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemFill))
                    .cornerRadius(6)
                    .accessibilityIdentifier("DemoTimerLabel")
            }

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

            Picker("Harness Scenario", selection: $model.scenario) {
                ForEach(DemoScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("HarnessScenarioPicker")

            Group {
                switch model.scenario {
                case .overview:
                    VStack(spacing: 12) {
                        UIKitSmokePanel()
                            .frame(height: 320)
                        WebViewSmokePanel(variant: .basic)
                            .frame(height: 150)
                    }
                case .runtimeBasic:
                    RuntimeBasicPanel(status: model.status)
                        .frame(height: 220)
                case .nativeControls:
                    UIKitSmokePanel()
                        .frame(height: 360)
                case .webViewBasic:
                    WebViewSmokePanel(variant: .basic)
                        .frame(height: 220)
                case .webViewEdge:
                    WebViewSmokePanel(variant: .edge)
                        .frame(height: 280)
                case .webViewNavigation:
                    WebViewSmokePanel(variant: .navigation)
                        .frame(height: 240)
                case .camera:
                    CameraSmokePanel()
                        .frame(height: 360)
                }
            }

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

struct RuntimeBasicPanel: View {
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("runtime-basic ready")
                .font(.headline)
                .accessibilityIdentifier("HarnessRuntimeReadyText")
            Text("scenario=runtime-basic status=\(status)")
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .accessibilityIdentifier("HarnessRuntimeStatusText")
            Text("capabilities=manifest,snapshot,observe,webview")
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .accessibilityIdentifier("HarnessRuntimeCapabilitiesText")
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .accessibilityIdentifier("HarnessRuntimePanel")
    }
}

struct UIKitSmokePanel: UIViewRepresentable {
    func makeUIView(context: Context) -> UIKitSmokeView {
        UIKitSmokeView()
    }

    func updateUIView(_ uiView: UIKitSmokeView, context: Context) {}
}

struct CameraSmokePanel: UIViewRepresentable {
    func makeUIView(context: Context) -> CameraSmokeView {
        CameraSmokeView()
    }

    func updateUIView(_ uiView: CameraSmokeView, context: Context) {}
}

final class CameraSmokeView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let statusLabel = UILabel()
    private let frameLabel = UILabel()
    private let previewView = UIView()
    private let previewImageView = UIImageView()
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "triton.demo.camera")
    private let imageContext = CIContext()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var frameCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        startCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
        startCamera()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = previewView.bounds
    }

    private func configureUI() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 8
        accessibilityIdentifier = "CameraHarnessPanel"

        statusLabel.text = "camera=starting"
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.accessibilityIdentifier = "CameraHarnessStatus"

        frameLabel.text = "frames=0"
        frameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        frameLabel.accessibilityIdentifier = "CameraHarnessFrameCount"

        previewView.backgroundColor = .black
        previewView.layer.cornerRadius = 6
        previewView.clipsToBounds = true
        previewView.accessibilityIdentifier = "CameraHarnessPreview"

        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewImageView.accessibilityIdentifier = "CameraHarnessPreviewImage"
        previewView.addSubview(previewImageView)
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewImageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: previewView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor)
        ])

        let stack = UIStackView(arrangedSubviews: [statusLabel, frameLabel, previewView])
        stack.axis = .vertical
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            previewView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])
    }

    private func startCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureCameraSession() : self?.setStatus("camera=denied")
                }
            }
            return
        }
        guard status == .authorized else {
            setStatus("camera=\(status)")
            return
        }
        configureCameraSession()
    }

    private func configureCameraSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            setStatus("camera=missing-device")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            previewView.layer.addSublayer(preview)
            previewLayer = preview
            setNeedsLayout()

            setStatus("camera=\(device.localizedName)")
            queue.async { [session] in
                session.startRunning()
            }
        } catch {
            setStatus("camera=error \(error.localizedDescription)")
        }
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = text
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        frameCount += 1
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let previewImage = makePreviewImage(from: imageBuffer)
        DispatchQueue.main.async {
            self.frameLabel.text = "frames=\(self.frameCount) size=\(width)x\(height)"
            if let previewImage {
                self.previewImageView.image = previewImage
            }
        }
    }

    private func makePreviewImage(from imageBuffer: CVImageBuffer) -> UIImage? {
        guard frameCount % 5 == 0 else {
            return nil
        }
        let image = CIImage(cvImageBuffer: imageBuffer)
        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

enum WebViewSmokeVariant {
    case basic
    case edge
    case navigation

    var baseURL: URL? {
        switch self {
        case .basic:
            return URL(string: "https://tritonkit.local/smoke")
        case .edge:
            return URL(string: "https://tritonkit.local/edge")
        case .navigation:
            return URL(string: "https://tritonkit.local/navigation")
        }
    }

    var html: String {
        switch self {
        case .basic:
            return Self.basicHTML
        case .edge:
            return Self.edgeHTML
        case .navigation:
            return Self.navigationHTML
        }
    }

    private static let sharedStyle = """
      <style>
        body { margin: 0; font: -apple-system-body; color: #111827; background: #eef6f2; }
        main { padding: 14px; }
        h1 { font-size: 18px; margin: 0 0 8px; }
        p { font-size: 13px; margin: 0 0 10px; color: #475569; }
        button { appearance: none; border: 0; border-radius: 6px; background: #0f766e; color: white; padding: 8px 12px; font-weight: 600; margin-right: 8px; }
        input { border: 1px solid #94a3b8; border-radius: 6px; padding: 7px 8px; width: 140px; margin: 0 8px 8px 0; }
        a { display: inline-block; margin: 0 8px 8px 0; color: #0f766e; }
      </style>
    """

    private static let basicHTML = """
    <!doctype html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Triton WebView Smoke</title>
      \(sharedStyle)
    </head>
    <body>
      <main>
        <h1>Triton WebView Smoke</h1>
        <p id="route">route=/smoke ready=true</p>
        <p id="submit-status">idle</p>
        <button id="submit">Submit</button>
        <input id="keyword" aria-label="Keyword" value="triton">
      </main>
      <script>
        document.getElementById("submit").addEventListener("click", function() {
          document.getElementById("submit-status").textContent = "submitted=true";
        });

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

    private static let edgeHTML = """
    <!doctype html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Triton WebView Edge</title>
      \(sharedStyle)
    </head>
    <body>
      <main>
        <h1>Triton WebView Edge</h1>
        <p id="edge-route">route=/edge ready=true long-text=abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz</p>
        <label for="keyword:edge.1">Edge Keyword</label>
        <input id="keyword:edge.1" name="keyword-edge" value="triton-edge">
        <label for="password:edge.1">Edge Secret</label>
        <input id="password:edge.1" name="edge-password" type="password" value="secret-value" autocomplete="off" autocorrect="off" autocapitalize="none" spellcheck="false">
        <input id="edge-extra-1" name="edge-extra-1" value="one">
        <input id="edge-extra-2" name="edge-extra-2" value="two">
        <input id="edge-extra-3" name="edge-extra-3" value="three">
        <input id="edge-extra-4" name="edge-extra-4" value="four">
        <a id="edge-link-1" href="https://tritonkit.local/edge/1">Edge Link 1</a>
        <a id="edge-link-2" href="https://tritonkit.local/edge/2">Edge Link 2</a>
        <a id="edge-link-3" href="https://tritonkit.local/edge/3">Edge Link 3</a>
        <a id="edge-link-4" href="https://tritonkit.local/edge/4">Edge Link 4</a>
        <a id="edge-link-5" href="https://tritonkit.local/edge/5">Edge Link 5</a>
        <button id="edge-ready">Edge Ready</button>
      </main>
      <script>
        window.__tritonBridge = {
          version: 1,
          methods: {
            getRouteState: function() {
              return {
                route: "/edge",
                title: document.title,
                ready: true
              };
            },
            emitEdgeEvent: function() {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.triton) {
                window.webkit.messageHandlers.triton.postMessage({
                  type: "event",
                  name: "edge.ready",
                  payload: { formCount: document.querySelectorAll("input").length }
                });
              }
              return { ok: true };
            }
          }
        };
      </script>
    </body>
    </html>
    """

    private static let navigationHTML = """
    <!doctype html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Triton WebView Navigation A</title>
      \(sharedStyle)
    </head>
    <body>
      <main>
        <h1 id="nav-title">Triton WebView Navigation A</h1>
        <p id="nav-route">route=/navigation/a ready=true</p>
        <button id="nav-button">Navigate</button>
      </main>
      <script>
        window.__tritonBridge = {
          version: 1,
          methods: {
            getRouteState: function() {
              return {
                route: location.pathname,
                title: document.title,
                ready: true
              };
            },
            navigateDetails: function() {
              history.pushState({}, "", "/navigation/b");
              document.title = "Triton WebView Navigation B";
              document.getElementById("nav-title").textContent = "Triton WebView Navigation B";
              document.getElementById("nav-route").textContent = "route=/navigation/b ready=true";
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.triton) {
                window.webkit.messageHandlers.triton.postMessage({
                  type: "event",
                  name: "navigation.changed",
                  payload: { route: "/navigation/b" }
                });
              }
              return { ok: true, route: "/navigation/b" };
            }
          }
        };
      </script>
    </body>
    </html>
    """
}

struct WebViewSmokePanel: UIViewRepresentable {
    let variant: WebViewSmokeVariant

    final class Coordinator {
        var loadedVariant: WebViewSmokeVariant?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.inputAssistantItem.leadingBarButtonGroups = []
        webView.inputAssistantItem.trailingBarButtonGroups = []
        webView.accessibilityIdentifier = "WebViewSmokeWebView"
        webView.scrollView.accessibilityIdentifier = "WebViewSmokeScrollView"
        webView.isOpaque = false
        webView.backgroundColor = .clear
        load(webView, context: context)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.loadedVariant != variant else { return }
        load(uiView, context: context)
    }

    private func load(_ webView: WKWebView, context: Context) {
        context.coordinator.loadedVariant = variant
        webView.loadHTMLString(variant.html, baseURL: variant.baseURL)
    }
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
