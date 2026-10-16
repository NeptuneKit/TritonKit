import Foundation
import Testing
@testable import TritonKit

struct TKSDKSettingsSnapshotTests {
    @Test("Connection status follows the supplied runtime state")
    func connectionStates() {
        let configuration = TritonKit.Configuration(endpoint: .local())
        #expect(TKSDKSettingsSnapshot(configuration: configuration, state: .disconnected).connectionTitle == "未连接")
        #expect(TKSDKSettingsSnapshot(configuration: configuration, state: .connecting).connectionTitle == "连接中")
        #expect(TKSDKSettingsSnapshot(configuration: configuration, state: .connected).connectionTitle == "已连接")
    }

    @Test("Server summary excludes data URL credentials and query parameters")
    func endpointOmitsCredentials() {
        let configuration = TritonKit.Configuration(endpoint: .init(
            host: "dev.local", port: 19422,
            dataURL: URL(string: "https://user:secret@dev.local:19422/data?token=private")
        ), autoReconnect: false)
        let snapshot = TKSDKSettingsSnapshot(configuration: configuration, state: .connected)
        #expect(snapshot.endpoint == "dev.local:19422")
        #expect(snapshot.reconnectTitle == "关闭")
        #expect(TKSDKSettingsSnapshot(configuration: .init(endpoint: .local()), state: .disconnected).reconnectTitle == "开启")
    }

    @Test("IPv6 endpoints have unambiguous brackets")
    func ipv6Endpoint() {
        for host in ["::1", "[::1]"] {
            let snapshot = TKSDKSettingsSnapshot(configuration: .init(endpoint: .init(host: host)), state: .disconnected)
            #expect(snapshot.endpoint == "[::1]:19421")
        }
    }

    @Test("All feature rows describe host configuration even when disconnected")
    func featureConfiguration() {
        let configuration = TritonKit.Configuration(endpoint: .local(), features: [.inspector, .webView])
        let snapshot = TKSDKSettingsSnapshot(configuration: configuration, state: .disconnected)
        #expect(snapshot.features.count == TritonKit.Feature.allCases.count)
        #expect(Set(snapshot.features.map(\.title)).count == snapshot.features.count)
        #expect(snapshot.features.filter(\.enabled).map(\.title) == ["控件选择器", "网页视图"])
        #expect(snapshot.features.first?.title == "属性高亮")
    }

    @Test("Unconsumed redaction policy does not appear as a working privacy control")
    func unimplementedPrivacyIsOmitted() {
        let configuration = TritonKit.Configuration(endpoint: .local(), redaction: .init(
            secureText: .hidden, collectClipboard: true, collectNetwork: true, collectLogs: true
        ))
        #expect(TKSDKSettingsSnapshot(configuration: configuration, state: .connected).privacy.isEmpty)
    }

    @Test("Application information only shows supplied facts in stable order")
    func suppliedAppInformation() {
        let snapshot = TKSDKSettingsSnapshot(configuration: .init(endpoint: .local()), state: .connected, appInfo: [
            "displayName": "Example", "name": "InternalName", "version": "2.3", "build": "45",
            "bundleIdentifier": "com.example.app", "os": "iOS 27", "sdkVersion": "invented",
        ])
        #expect(snapshot.app.map(\.title) == ["应用", "版本", "构建", "标识符", "系统"])
        #expect(snapshot.app.map(\.value) == ["Example", "2.3", "45", "com.example.app", "iOS 27"])
    }

    @Test("Empty information is omitted and bundle keys are supported")
    func absentAppInformation() {
        let configuration = TritonKit.Configuration(endpoint: .local())
        #expect(TKSDKSettingsSnapshot(configuration: configuration, state: .connected).app.isEmpty)
        let snapshot = TKSDKSettingsSnapshot(configuration: configuration, state: .connected, appInfo: [
            "displayName": "  ", "CFBundleName": "HostApp", "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "4", "CFBundleIdentifier": "com.example.host", "os": "",
        ])
        #expect(snapshot.app.map(\.value) == ["HostApp", "1.0", "4", "com.example.host"])
    }
}
