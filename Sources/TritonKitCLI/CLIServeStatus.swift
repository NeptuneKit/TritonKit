import Hummingbird
import TritonKitShared

func registerTritonStatusRoute<Context: RequestContext>(on router: Router<Context>, state: ConnectionState, publisher: TritonBonjourPublisher) {
    router.get("/status") { _, _ -> Response in
        let cache = state.cacheStatus()
        return jsonResponse(TKStatusResponse(
            connected: state.isConnected,
            latestHierarchyAvailable: cache.latestHierarchyAvailable,
            targetCount: state.targetCount,
            activeHierarchyAvailable: cache.activeHierarchyAvailable,
            hierarchyCacheState: cache.hierarchyCacheState,
            targetConnectionState: state.isConnected ? "connected" : "disconnected",
            discovery: publisher.snapshot
        ))
    }
}
