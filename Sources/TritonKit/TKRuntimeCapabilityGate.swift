import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

enum TKRuntimeCapabilityGate {
    static func disabledResponse(for message: TKMessage, configuration: TritonKit.Configuration) -> TKMessage? {
        guard let capability = capability(for: message),
              !configuration.isRuntimeCapabilityEnabled(capability) else {
            return nil
        }

        let action = actionName(for: message)
        let error = runtimeCapabilityDisabledError(capability: capability, action: action)

        switch message.type {
        case .input:
            let input = message.payload.flatMap { try? JSONDecoder().decode(TKInputRequest.self, from: $0) }
            let result = TKInputResult.failure(
                action: input?.type.rawValue ?? "input",
                message: error.message,
                error: error
            )
            return TKMessage(id: message.id, type: .input, payload: try? JSONEncoder().encode(result))

        case .semanticAction:
            let request = message.payload.flatMap { try? JSONDecoder().decode(TKSemanticActionRequest.self, from: $0) }
            let response = TKSemanticActionResponse(
                ok: false,
                action: request?.action ?? .focus,
                strategy: request?.strategy ?? "capability-disabled",
                elapsedMs: 0,
                message: error.message,
                error: error
            )
            return TKMessage(id: message.id, type: .semanticAction, payload: try? JSONEncoder().encode(response))

        case .webViewList, .webViewCurrent, .webViewSnapshot, .webViewBridgeCall, .webViewBridgePost, .webViewWait, .webViewEvents, .webViewLedger:
            let response = TKWebViewErrorResponse(
                action: action,
                platform: "ios",
                target: "embedded-runtime",
                error: error
            )
            return TKMessage(id: message.id, type: message.type, payload: try? JSONEncoder().encode(response))

        default:
            return TKMessage(id: message.id, type: message.type, payload: try? JSONEncoder().encode(TKCLIErrorResponse(error: error)))
        }
    }

    static func capability(for message: TKMessage) -> TKRuntimeCapabilityName? {
        switch message.type {
        case .appInfo:
            return .appInfo
        case .stateApp:
            return .stateApp
        case .stateScene:
            return .stateScene
        case .stateRoute:
            return .stateRoute
        case .stateResponder:
            return .stateResponder
        case .runtimeSnapshot:
            return .snapshot
        case .webViewList:
            return .webViewList
        case .webViewCurrent:
            return .webViewCurrent
        case .webViewSnapshot:
            return .webViewSnapshot
        case .webViewBridgeCall, .webViewBridgePost, .webViewLedger:
            return .webViewBridgeCall
        case .webViewWait:
            return .webViewWait
        case .webViewEvents:
            return .webViewEvents
        case .semanticAction:
            let request = message.payload.flatMap { try? JSONDecoder().decode(TKSemanticActionRequest.self, from: $0) }
            switch request?.action {
            case .focus:
                return .semanticFocus
            case .setText:
                return .semanticSetText
            case .selectSegment:
                return .semanticSelectSegment
            case .setSwitch:
                return .semanticSetSwitch
            case nil:
                return .semanticFocus
            }
        case .hierarchy, .hierarchyDetails, .allAttrGroups, .modifyAttribute, .modifyAttributePatch, .invokeMethod, .fetchObject, .fetchImageViewImage, .modifyRecognizerEnable, .allSelectorNames, .modifyCustomAttribute, .cancelHierarchyDetails:
            return .hierarchy
        case .input:
            let request = message.payload.flatMap { try? JSONDecoder().decode(TKInputRequest.self, from: $0) }
            switch request?.type {
            case .tap, .longPress:
                return .inputTap
            case .swipe, .pinch:
                return .inputSwipe
            case .typeText:
                return .inputType
            case .paste:
                return .inputPaste
            case .clear, .deleteBackward:
                return .inputClear
            case .button:
                return .press
            case nil:
                return .inputTap
            }
        case .accessibility:
            return .accessibility
        case .hitTest:
            return .hitTest
        case .screenshot:
            return .screenshot
        case .geometry:
            return .geometry
        case .ping, .runtimeManifest, .runtimeLedger:
            return nil
        }
    }

    static func actionName(for message: TKMessage) -> String {
        switch message.type {
        case .input:
            return message.payload
                .flatMap { try? JSONDecoder().decode(TKInputRequest.self, from: $0) }?
                .type.rawValue ?? "input"
        case .semanticAction:
            return message.payload
                .flatMap { try? JSONDecoder().decode(TKSemanticActionRequest.self, from: $0) }?
                .action.rawValue ?? "semanticAction"
        case .webViewList:
            return "webview.list"
        case .webViewCurrent:
            return "webview.current"
        case .webViewSnapshot:
            return "webview.snapshot"
        case .webViewBridgeCall:
            return "webview.call"
        case .webViewBridgePost:
            return "webview.post"
        case .webViewWait:
            return "webview.wait"
        case .webViewEvents:
            return "webview.events"
        case .webViewLedger:
            return "webview.ledger"
        default:
            return message.type.rawValue
        }
    }
}

extension TritonKit.Configuration {
    func isRuntimeCapabilityEnabled(_ capability: TKRuntimeCapabilityName) -> Bool {
        switch capability {
        case .runtimeManifest, .ledger:
            return true
        case .appInfo, .stateApp, .stateScene, .stateRoute, .stateResponder:
            return features.contains(.appInfo)
        case .hierarchy:
            return features.contains(.hierarchy)
        case .accessibility:
            return features.contains(.accessibility)
        case .geometry, .hitTest:
            return features.contains(.geometry)
        case .screenshot:
            return features.contains(.screenshot)
        case .snapshot:
            return !features.intersection([.appInfo, .hierarchy, .accessibility, .geometry, .screenshot, .semantic]).isEmpty
        case .mediaPlayback:
            return features.contains(.accessibility)
        case .semanticState, .semanticActionProvider:
            return features.contains(.semantic)
        case .webViewList, .webViewCurrent, .webViewSnapshot, .webViewBridgeCall, .webViewBridgePost, .webViewWait, .webViewEvents:
            return features.contains(.webView)
        case .webViewEval:
            return false
        case .semanticFocus, .semanticSetText, .semanticSelectSegment, .semanticSetSwitch:
            return features.contains(.input)
        case .inputTap, .inputSwipe, .inputType, .inputPaste, .inputClear:
            return features.contains(.input)
        case .press, .systemAlerts, .networkBreadcrumbs:
            return false
        }
    }
}
