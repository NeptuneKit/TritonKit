import Foundation
#if !TRITONKIT_COCOAPODS_SINGLE_POD
import TritonKitShared
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AVKit)
import AVKit
#endif

#if canImport(UIKit)
@MainActor
func currentMediaState(axNodes: [TKAXNode]?) -> TKRuntimeMediaStateResponse {
    var surfaces: [TKRuntimeMediaSurface] = []
    let windows = keyWindows()

    for (windowIndex, window) in windows.enumerated() {
        surfaces.append(contentsOf: mediaLayerSurfaces(in: window, windowIndex: windowIndex))
    }

    #if canImport(AVKit)
    let controllers = windows.compactMap(\.rootViewController).flatMap(mediaControllerTree)
    for controller in controllers {
        guard let playerController = controller as? AVPlayerViewController else { continue }
        let frame = playerController.view.window.map { tkRect(playerController.view.convert(playerController.view.bounds, to: $0)) }
        surfaces.append(mediaSurface(
            id: "media-controller-\(surfaces.count + 1)",
            kind: "avplayer-view-controller",
            className: NSStringFromClass(type(of: playerController)),
            frame: frame,
            visible: isAXVisible(playerController.view),
            player: playerController.player,
            controllerClassName: NSStringFromClass(type(of: playerController))
        ))
    }
    #endif

    let controls = TKRuntimeMediaControlCandidates(from: axNodes ?? [])
    let warnings = surfaces.isEmpty
        ? ["No AVPlayer-backed media surface was discovered from public runtime APIs"]
        : []

    return TKRuntimeMediaStateResponse(
        capturedAt: currentStateTimestamp(),
        surfaces: deduplicateMediaSurfaces(surfaces),
        controls: controls,
        warnings: warnings
    )
}

@MainActor
private func mediaLayerSurfaces(in window: UIWindow, windowIndex: Int) -> [TKRuntimeMediaSurface] {
    var surfaces: [TKRuntimeMediaSurface] = []

    func walk(view: UIView) {
        surfaces.append(contentsOf: mediaLayerSurfaces(
            layer: view.layer,
            window: window,
            prefix: "window-\(windowIndex)-view-\(oid(for: view) ?? 0)",
            controllerClassName: nearestViewControllerClassName(from: view)
        ))
        for subview in view.subviews {
            walk(view: subview)
        }
    }

    walk(view: window)
    return surfaces
}

@MainActor
private func mediaLayerSurfaces(
    layer: CALayer,
    window: UIWindow,
    prefix: String,
    controllerClassName: String?
) -> [TKRuntimeMediaSurface] {
    var surfaces: [TKRuntimeMediaSurface] = []

    #if canImport(AVFoundation)
    if let playerLayer = layer as? AVPlayerLayer {
        let frame = tkRect(window.layer.convert(playerLayer.bounds, from: playerLayer))
        surfaces.append(mediaSurface(
            id: "\(prefix)-layer-\(ObjectIdentifier(playerLayer).hashValue)",
            kind: "avplayer-layer",
            className: NSStringFromClass(type(of: playerLayer)),
            frame: frame,
            visible: !playerLayer.isHidden && playerLayer.opacity > 0 && playerLayer.bounds.width > 0 && playerLayer.bounds.height > 0,
            player: playerLayer.player,
            controllerClassName: controllerClassName
        ))
    }
    #endif

    for sublayer in layer.sublayers ?? [] {
        surfaces.append(contentsOf: mediaLayerSurfaces(
            layer: sublayer,
            window: window,
            prefix: prefix,
            controllerClassName: controllerClassName
        ))
    }

    return surfaces
}

#if canImport(AVFoundation)
private func mediaSurface(
    id: String,
    kind: String,
    className: String,
    frame: TKRect?,
    visible: Bool,
    player: AVPlayer?,
    controllerClassName: String?
) -> TKRuntimeMediaSurface {
    let elapsed = player.map { seconds(from: $0.currentTime()) }
    let duration = player?.currentItem.map { seconds(from: $0.duration) }
    let boundedDuration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    let progress = if let elapsed, let boundedDuration {
        min(max(elapsed / boundedDuration, 0), 1)
    } else {
        Optional<Double>.none
    }

    return TKRuntimeMediaSurface(
        id: id,
        kind: kind,
        className: className,
        frame: frame,
        visible: visible,
        playerStatus: player?.currentItem.map { playerItemStatusName($0.status) },
        playbackState: playerPlaybackState(player),
        rate: player.map { Double($0.rate) },
        elapsedTimeSeconds: elapsed?.isFinite == true ? elapsed : nil,
        durationSeconds: boundedDuration,
        progress: progress,
        controllerClassName: controllerClassName
    )
}

private func seconds(from time: CMTime) -> Double {
    guard time.isValid, !time.isIndefinite else { return .nan }
    return CMTimeGetSeconds(time)
}

private func playerItemStatusName(_ status: AVPlayerItem.Status) -> String {
    switch status {
    case .unknown: return "unknown"
    case .readyToPlay: return "readyToPlay"
    case .failed: return "failed"
    @unknown default: return "unknown"
    }
}

private func playerPlaybackState(_ player: AVPlayer?) -> String? {
    guard let player else { return nil }
    if player.rate > 0 {
        return "playing"
    }
    switch player.timeControlStatus {
    case .paused: return "paused"
    case .waitingToPlayAtSpecifiedRate: return "waiting"
    case .playing: return "playing"
    @unknown default: return "unknown"
    }
}
#else
private func mediaSurface(
    id: String,
    kind: String,
    className: String,
    frame: TKRect?,
    visible: Bool,
    player: Any?,
    controllerClassName: String?
) -> TKRuntimeMediaSurface {
    TKRuntimeMediaSurface(
        id: id,
        kind: kind,
        className: className,
        frame: frame,
        visible: visible,
        controllerClassName: controllerClassName
    )
}
#endif

@MainActor
private func mediaControllerTree(_ root: UIViewController) -> [UIViewController] {
    var controllers = [root]
    controllers.append(contentsOf: root.children.flatMap(mediaControllerTree))
    if let presented = root.presentedViewController {
        controllers.append(contentsOf: mediaControllerTree(presented))
    }
    return controllers
}

@MainActor
private func nearestViewControllerClassName(from view: UIView) -> String? {
    var responder: UIResponder? = view
    while let current = responder {
        if let controller = current as? UIViewController {
            return NSStringFromClass(type(of: controller))
        }
        responder = current.next
    }
    return nil
}

private func deduplicateMediaSurfaces(_ surfaces: [TKRuntimeMediaSurface]) -> [TKRuntimeMediaSurface] {
    var seen = Set<String>()
    return surfaces.filter { surface in
        let key = [
            surface.kind,
            surface.className,
            surface.controllerClassName ?? "",
            surface.frame.map { "\($0.x),\($0.y),\($0.width),\($0.height)" } ?? "",
        ].joined(separator: "|")
        return seen.insert(key).inserted
    }
}
#else
func currentMediaState(axNodes: [TKAXNode]?) -> TKRuntimeMediaStateResponse {
    TKRuntimeMediaStateResponse(
        capturedAt: currentStateTimestamp(),
        surfaces: [],
        controls: TKRuntimeMediaControlCandidates(from: axNodes ?? []),
        unsupported: [
            TKRuntimeUnsupportedState(field: "media", reason: "UIKit is not available on this platform"),
        ]
    )
}
#endif
