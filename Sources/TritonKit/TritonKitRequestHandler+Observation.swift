import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

extension TritonKitRequestHandler {
    func handleObservation(_ message: TKMessage) async -> TKMessage? {
        switch message.type {
        case .appInfo:
            let appInfo = TKAppInfo()
            let info = TKHierarchyInfo(displayItems: [], appInfo: appInfo)
            return TKMessage(id: message.id, type: .appInfo, payload: try? JSONEncoder().encode(info))

        case .stateApp:
            #if canImport(UIKit)
            let state = await MainActor.run { currentAppState() }
            #else
            let state = TKRuntimeAppStateResponse(
                capturedAt: currentStateTimestamp(),
                app: TKRuntimeAppState(
                    bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                    displayName: Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "",
                    version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                    localeIdentifier: Locale.current.identifier,
                    preferredLanguages: Locale.preferredLanguages,
                    userInterfaceStyle: "unknown",
                    processUptimeSeconds: ProcessInfo.processInfo.systemUptime,
                    sceneCount: 0,
                    windowCount: 0
                ),
                unsupported: [TKRuntimeUnsupportedState(field: "uikit", reason: "App state scene details require UIKit runtime")]
            )
            #endif
            return TKMessage(id: message.id, type: .stateApp, payload: try? JSONEncoder().encode(state))

        case .stateScene:
            #if canImport(UIKit)
            let state = await MainActor.run { currentSceneState() }
            #else
            let state = TKRuntimeSceneStateResponse(
                capturedAt: currentStateTimestamp(),
                scenes: [],
                unsupported: [TKRuntimeUnsupportedState(field: "scenes", reason: "Scene state requires UIKit runtime")]
            )
            #endif
            return TKMessage(id: message.id, type: .stateScene, payload: try? JSONEncoder().encode(state))

        case .stateRoute:
            #if canImport(UIKit)
            let state = await MainActor.run { currentRouteState() }
            #else
            let state = TKRuntimeRouteStateResponse(
                capturedAt: currentStateTimestamp(),
                unsupported: [TKRuntimeUnsupportedState(field: "route", reason: "Route state requires UIKit runtime")]
            )
            #endif
            return TKMessage(id: message.id, type: .stateRoute, payload: try? JSONEncoder().encode(state))

        case .stateResponder:
            #if canImport(UIKit)
            let state = await MainActor.run { currentResponderState() }
            #else
            let state = TKRuntimeResponderStateResponse(
                capturedAt: currentStateTimestamp(),
                unsupported: [TKRuntimeUnsupportedState(field: "firstResponder", reason: "Responder state requires UIKit runtime")]
            )
            #endif
            return TKMessage(id: message.id, type: .stateResponder, payload: try? JSONEncoder().encode(state))

        case .runtimeSnapshot:
            let request = message.payload.flatMap { try? JSONDecoder().decode(TKRuntimeSnapshotRequest.self, from: $0) } ?? TKRuntimeSnapshotRequest()
            #if canImport(UIKit)
            let snapshot = await MainActor.run { currentRuntimeSnapshot(request) }
            #else
            let snapshot = TKRuntimeSnapshotResponse(
                capturedAt: currentStateTimestamp(),
                include: request.include,
                skipped: request.include.map { TKRuntimeSnapshotSkipped(name: $0, reason: "Runtime snapshot requires UIKit runtime") }
            )
            #endif
            return TKMessage(id: message.id, type: .runtimeSnapshot, payload: try? JSONEncoder().encode(snapshot))

        case .hierarchy:
            let uploader = kit?.uploader
            var items = await TKHierarchyBuilder.buildHierarchy(includeScreenshots: uploader != nil)
            if let uploader {
                items = await uploadHierarchyScreenshots(items, uploader: uploader)
            }
            let appInfo = TKAppInfo()
            #if canImport(UIKit)
            let controllerContext = await MainActor.run { currentHierarchyControllerContext() }
            #else
            let controllerContext: TKHierarchyControllerContext? = nil
            #endif
            let hierarchy = TKHierarchyInfo(displayItems: items, appInfo: appInfo, controllerContext: controllerContext)
            do {
                return TKMessage(id: message.id, type: .hierarchy, payload: try JSONEncoder().encode(hierarchy))
            } catch {
                #if canImport(Foundation)
                NSLog("[TritonKit] hierarchy encode failed: \(error)")
                #endif
                return errorResponse(id: message.id, message: "Hierarchy encode failed: \(error)")
            }

        case .accessibility:
            #if canImport(UIKit)
            let nodes = await MainActor.run {
                var context = AXBuildContext()
                return keyWindows().map { window in
                    buildAXWindowNode(for: window, context: &context)
                }
            }
            return TKMessage(id: message.id, type: .accessibility, payload: try? JSONEncoder().encode(nodes))
            #else
            return TKMessage(id: message.id, type: .accessibility, payload: try? JSONEncoder().encode([TKAXNode]()))
            #endif

        case .hitTest:
            guard let data = message.payload,
                  let request = try? JSONDecoder().decode(TKHitTestRequest.self, from: data) else {
                return errorResponse(id: message.id, message: "Missing or invalid hitTest payload")
            }
            #if canImport(UIKit)
            let response = await MainActor.run {
                performHitTest(request)
            }
            return TKMessage(id: message.id, type: .hitTest, payload: try? JSONEncoder().encode(response))
            #else
            return TKMessage(id: message.id, type: .hitTest,
                payload: try? JSONEncoder().encode(TKHitTestResponse(x: request.x, y: request.y, node: nil)))
            #endif

        case .geometry:
            #if canImport(UIKit)
            let geometry = await MainActor.run {
                currentGeometry()
            }
            return TKMessage(id: message.id, type: .geometry, payload: try? JSONEncoder().encode(geometry))
            #else
            let geometry = TKGeometryResponse(
                bounds: TKRect(x: 0, y: 0, width: 0, height: 0),
                safeArea: TKInsets(top: 0, left: 0, bottom: 0, right: 0),
                scale: 1,
                orientation: "unknown"
            )
            return TKMessage(id: message.id, type: .geometry, payload: try? JSONEncoder().encode(geometry))
            #endif

        case .screenshot:
            #if canImport(UIKit)
            let capture = await MainActor.run {
                captureCurrentScreenshotData()
            }
            let screenshot: TKScreenshotResponse
            if let dataRef = try? await kit?.uploader?.upload(capture.data) {
                screenshot = TKScreenshotResponse(
                    format: capture.format,
                    width: capture.width,
                    height: capture.height,
                    scale: capture.scale,
                    dataBase64: "",
                    dataRef: dataRef
                )
            } else {
                screenshot = TKScreenshotResponse(
                    format: capture.format,
                    width: capture.width,
                    height: capture.height,
                    scale: capture.scale,
                    dataBase64: capture.data.base64EncodedString()
                )
            }
            return TKMessage(id: message.id, type: .screenshot, payload: try? JSONEncoder().encode(screenshot))
            #else
            let screenshot = TKScreenshotResponse(format: "png", width: 0, height: 0, scale: 1, dataBase64: "")
            return TKMessage(id: message.id, type: .screenshot, payload: try? JSONEncoder().encode(screenshot))
            #endif

        default:
            return unsupportedMessage(message)
        }
    }

    private func uploadHierarchyScreenshots(
        _ items: [TKDisplayItem],
        uploader: TritonKitDataUploader
    ) async -> [TKDisplayItem] {
        var result: [TKDisplayItem] = []
        result.reserveCapacity(items.count)
        for var item in items {
            item.subitems = await uploadHierarchyScreenshots(item.subitems, uploader: uploader)
            if let screenshot = item.groupScreenshot ?? item.soloScreenshot,
               let ref = try? await uploader.upload(screenshot) {
                item.screenshotRef = ref
            }
            item.groupScreenshot = nil
            item.soloScreenshot = nil
            result.append(item)
        }
        return result
    }
}
