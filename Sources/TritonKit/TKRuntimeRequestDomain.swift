#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif

enum TKRuntimeRequestDomain: Equatable {
    case control
    case observation
    case input
    case webView
    case semantic
    case ledger
    case legacyInspection
    case unsupported

    static func domain(for type: TKRequestType) -> TKRuntimeRequestDomain {
        switch type {
        case .ping, .runtimeManifest:
            return .control
        case .appInfo, .stateApp, .stateScene, .stateRoute, .stateResponder, .runtimeSnapshot, .hierarchy, .accessibility, .hitTest, .screenshot, .geometry:
            return .observation
        case .input:
            return .input
        case .webViewList, .webViewCurrent, .webViewSnapshot, .webViewBridgeCall, .webViewBridgePost, .webViewWait, .webViewEvents, .webViewLedger:
            return .webView
        case .semanticAction:
            return .semantic
        case .runtimeLedger:
            return .ledger
        case .hierarchyDetails, .allAttrGroups, .modifyAttribute, .invokeMethod, .fetchObject:
            return .legacyInspection
        case .modifyAttributePatch, .fetchImageViewImage, .modifyRecognizerEnable, .allSelectorNames, .modifyCustomAttribute, .cancelHierarchyDetails:
            return .unsupported
        }
    }
}
