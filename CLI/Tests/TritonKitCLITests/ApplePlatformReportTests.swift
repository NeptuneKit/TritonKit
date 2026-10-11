import Foundation
import Testing
import TritonKitShared
@testable import TritonKitCLI

@Suite("Apple platform report fails closed without changing legacy targets")
struct ApplePlatformReportTests {
    @Test func catalogWithoutIO() throws {
        var calls = 0
        let report = try makeApplePlatformReport(simulatorProvider: { calls += 1; return [] })
        #expect(calls == 0 && !report.inventoryObserved && report.simulatorCounts.isEmpty && report.sourceCommands.isEmpty)
        #expect(report.profiles.count == 6 && !report.physicalInventoryObserved && !report.actionsExecuted)
        #expect(report.profiles.allSatisfy { !$0.platformSpecificControlAccepted && !$0.actionsAuthorized && !$0.missingCapabilities.isEmpty })
        let selected = try makeApplePlatformReport(family: .watchos, simulatorProvider: { calls += 1; return [] })
        #expect(selected.profiles.count == 1 && selected.profiles.first?.family == .watchos && calls == 0)
        #expect(throws: HostDeviceSelectionError.self) { _ = try makeApplePlatformReport(inventory: true, family: .unknown, simulatorProvider: { calls += 1; return [] }) }
        #expect(calls == 0)
    }
    @Test func strictMetadataClassification() {
        for (component, expected) in [("iOS", HostApplePlatformFamily.ios), ("watchOS", .watchos), ("tvOS", .tvos), ("xrOS", .visionos), ("visionOS", .visionos)] {
            #expect(appleSimulatorPlatformFamily(runtime: "com.apple.CoreSimulator.SimRuntime." + component + "-27-0") == expected)
        }
        for value in [nil, "iOS 27", "com.apple.CoreSimulator.SimRuntime.iPadOS-27-0", "com.apple.CoreSimulator.SimRuntime.macOS-27-0", "com.apple.CoreSimulator.SimRuntime.iOS-27-beta", "com.apple.CoreSimulator.SimRuntime.iOS-٢٧-0", "com.apple.CoreSimulator.SimRuntime.iOS-27--0", "com.apple.CoreSimulator.SimRuntime.iOS-27-0\nPRIVATE", "com.apple.CoreSimulator.SimRuntime.iOS-27-0-0-0-0"] {
            #expect(appleSimulatorPlatformFamily(runtime: value) == .unknown)
        }
    }
    @Test func singleMetadataQueryNoNameInferenceOrRawEcho() throws {
        // Exercise the native parser boundary instead of injecting identifiers
        // into HostDeviceTarget.runtime, which is a human-readable display value.
        let data = Data(#"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"PRIVATE-IOS-0","name":"PRIVATE-iPad","state":"Shutdown","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.iOS-27-1":[{"udid":"PRIVATE-IOS-1","name":"PRIVATE-Apple-Watch","state":"Shutdown","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.watchOS-27-0":[{"udid":"PRIVATE-WATCH","name":"PRIVATE-iPhone","state":"Shutdown","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.tvOS-27-0":[{"udid":"PRIVATE-TV","name":"PRIVATE-TV","state":"Shutdown","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.xrOS-27-0":[{"udid":"PRIVATE-VISION","name":"PRIVATE-Vision","state":"Shutdown","isAvailable":true}],"PRIVATE-RUNTIME":[{"udid":"PRIVATE-UNKNOWN","name":"PRIVATE-iPhone","state":"Shutdown","isAvailable":true}],"iOS 27.0":[{"udid":"PRIVATE-DISPLAY","name":"PRIVATE-iPad","state":"Shutdown","isAvailable":true}]}}"#.utf8)
        let targets = try TKSimctlDeviceListParser.parse(data)
        let ios = try #require(targets.first { $0.udid == "PRIVATE-IOS-0" })
        #expect(hostDeviceTarget(from: ios).runtime == "iOS 27.0")
        var calls = 0
        let report = try makeApplePlatformReport(inventory: true, family: .ipados, simulatorProvider: {
            calls += 1
            return targets
        })
        #expect(calls == 1 && report.inventoryObserved && report.profiles.count == 1 && report.profiles.first?.family == .ipados)
        #expect(report.simulatorCounts.first { $0.family == .ios }?.count == 2)
        #expect(report.simulatorCounts.first { $0.family == .watchos }?.count == 1)
        #expect(report.simulatorCounts.first { $0.family == .tvos }?.count == 1)
        #expect(report.simulatorCounts.first { $0.family == .visionos }?.count == 1)
        #expect(report.simulatorCounts.first { $0.family == .ipados }?.count == 0)
        #expect(report.simulatorCounts.first { $0.family == .unknown }?.count == 2)
        let text = try encodeJSON(report)
        #expect(!text.contains("PRIVATE") && !text.contains("com.apple.CoreSimulator.SimRuntime"))
        #expect(!report.physicalInventoryObserved && !report.actionsExecuted && report.sourceCommands.count == 1)
    }
    @Test func explicitPhysicalInventoryAndSelection() throws {
        let data = Data(#"{"info":{"outcome":"success"},"result":{"devices":[{"identifier":"PRIVATE-WATCH","properties":{"hardware":{"platform":"watchOS","deviceType":"AppleWatch","reality":"physical"}}}]}}"#.utf8)
        var calls = 0
        let report = try makeApplePlatformReport(includeRealDevices: true, device: "PRIVATE-WATCH", physicalProvider: { calls += 1; return data })
        #expect(calls == 1 && report.physicalInventoryObserved && report.physicalDevices.count == 1)
        #expect(report.physicalDevices[0].observation.systemFamily == .watchos)
        #expect(!report.inventoryObserved && report.simulatorCounts.isEmpty && !report.actionsExecuted)
        #expect(try !encodeJSON(report).contains("PRIVATE-WATCH"))
        #expect(throws: HostDeviceSelectionError.self) { _ = try makeApplePlatformReport(device: "PRIVATE-WATCH", physicalProvider: { calls += 1; return data }) }
        #expect(calls == 1)
        #expect(throws: HostDeviceSelectionError.self) { _ = try makeApplePlatformReport(includeRealDevices: true, device: "missing", physicalProvider: { data }) }
    }
    @Test func failurePrivacy() throws {
        do { _ = try makeApplePlatformReport(inventory: true, simulatorProvider: { throw NSError(domain: "PRIVATE", code: 1, userInfo: [NSLocalizedDescriptionKey: "PRIVATE-LOG-PATH"]) }); Issue.record("expected failure") }
        catch { #expect(error is HostApplePlatformInventoryFailure); #expect(!String(describing: error).contains("PRIVATE")) }
    }
}
