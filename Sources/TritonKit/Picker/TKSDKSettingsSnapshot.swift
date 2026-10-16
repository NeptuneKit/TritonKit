import Foundation

/// Read-only presentation of runtime state and host configuration.
/// Feature membership describes configuration, not platform capability or live availability.
struct TKSDKSettingsSnapshot {
    struct InfoRow {
        let title: String
        let value: String
    }

    struct FeatureRow {
        let title: String
        let enabled: Bool
    }

    let connectionTitle: String
    let endpoint: String
    let reconnectTitle: String
    let features: [FeatureRow]
    let privacy: [InfoRow]
    let app: [InfoRow]

    init(
        configuration: TritonKit.Configuration,
        state: TritonKit.ConnectionState,
        appInfo: [String: String] = [:]
    ) {
        switch state {
        case .disconnected: connectionTitle = "未连接"
        case .connecting: connectionTitle = "连接中"
        case .connected: connectionTitle = "已连接"
        }

        // Do not display dataURL: it can contain credentials or token-bearing queries.
        let host = configuration.endpoint.host
        let displayHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        endpoint = "\(displayHost):\(configuration.endpoint.port)"
        reconnectTitle = configuration.autoReconnect ? "开启" : "关闭"
        features = TritonKit.Feature.allCases.map {
            FeatureRow(title: Self.title(for: $0), enabled: configuration.features.contains($0))
        }

        // RedactionPolicy is currently configuration-only; exposing it here as
        // enforced protection would misrepresent the runtime's implementation.
        privacy = []

        let fields: [(String, [String])] = [
            ("应用", ["displayName", "CFBundleDisplayName", "name", "CFBundleName"]),
            ("版本", ["version", "CFBundleShortVersionString"]),
            ("构建", ["build", "CFBundleVersion"]),
            ("标识符", ["bundleIdentifier", "CFBundleIdentifier"]),
            ("系统", ["os"]),
        ]
        app = fields.compactMap { title, keys in
            guard let value = keys.compactMap({ appInfo[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty }) else { return nil }
            return InfoRow(title: title, value: value)
        }
    }

    private static func title(for feature: TritonKit.Feature) -> String {
        switch feature {
        case .highlight: return "属性高亮"
        case .inspector: return "控件选择器"
        case .appInfo: return "应用信息"
        case .hierarchy: return "视图层级"
        case .accessibility: return "无障碍树"
        case .geometry: return "布局几何"
        case .screenshot: return "截图"
        case .input: return "输入操作"
        case .webView: return "网页视图"
        case .semantic: return "语义信息"
        }
    }
}
