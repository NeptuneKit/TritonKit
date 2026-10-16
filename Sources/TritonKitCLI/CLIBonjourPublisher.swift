import Foundation
import TritonKitShared

/// Owns a dedicated run loop: an async CLI executor does not necessarily pump the
/// Foundation run loop on which NetService delivers its publication callbacks.
final class TritonBonjourPublisher: NSObject, NetServiceDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let wanted: Bool
    private let port: Int
    private let serviceType: String
    private let name: String
    private var status: TKDiscoveryStatus
    private var service: NetService?
    private var completion: DispatchSemaphore?
    private var stopRequested = false

    init(wanted: Bool, port: Int, serviceType: String = "_tritonkit-server._tcp.", name: String = "TritonKit") {
        self.wanted = wanted
        self.port = port
        self.serviceType = serviceType
        self.name = name
        self.status = TKDiscoveryStatus(wanted: wanted, state: wanted ? "wanted" : "stopped", serviceType: serviceType)
    }

    var snapshot: TKDiscoveryStatus { lock.withLock { status } }

    func start() {
        if snapshot.state == "failed" { stop() }
        let done = DispatchSemaphore(value: 0)
        let shouldStart = lock.withLock {
            guard wanted, completion == nil else { return false }
            completion = done
            stopRequested = false
            setState("wanted")
            return true
        }
        guard shouldStart else { return }
        Thread.detachNewThread { [self] in
            let candidate = NetService(domain: "local.", type: serviceType, name: name, port: Int32(clamping: port))
            begin(candidate)
            candidate.delegate = self
            candidate.schedule(in: .current, forMode: .default)
            let publishRequested = !lock.withLock { stopRequested }
            if publishRequested { candidate.publish() }
            while lock.withLock({ !stopRequested && service === candidate && status.state != "failed" }) {
                pumpRunLoop()
            }
            candidate.stop()
            if publishRequested {
                // stop() requests withdrawal; only didStop confirms it. Keep pumping
                // even after a failure so the owned publication is fully cleaned up.
                while lock.withLock({ service === candidate }) { pumpRunLoop() }
            } else {
                lock.withLock { service = nil; setState("stopped") }
            }
            candidate.remove(from: .current, forMode: .default)
            candidate.delegate = nil
            lock.withLock { completion = nil }
            done.signal()
        }
    }

    /// Stop only resources owned by this publisher. The worker withdraws the record
    /// before publishing a stopped state; a bounded wait never invents success.
    func stop() {
        let done = lock.withLock {
            stopRequested = true
            if completion == nil && service == nil { setState("stopped") }
            return completion
        }
        _ = done?.wait(timeout: .now() + 2)
    }

    // Shared by the real worker and deterministic callback tests; no publication here.
    func begin(_ candidate: NetService) {
        lock.withLock {
            guard wanted else { return }
            service = candidate
            setState("publishing")
        }
    }

    func netServiceDidPublish(_ sender: NetService) {
        let published = lock.withLock {
            guard service === sender, status.state == "publishing", !stopRequested else { return false }
            setState("advertising")
            return true
        }
        if published { log("[tritonkit] Bonjour: advertising \(serviceType) on port \(port) (discovery only; peer identity unverified)") }
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let failed = lock.withLock {
            guard service === sender, ["publishing", "advertising"].contains(status.state), !stopRequested else { return false }
            status = TKDiscoveryStatus(wanted: wanted, state: "failed", serviceType: serviceType,
                errorCode: errorDict[NetService.errorCode]?.intValue,
                errorDomain: errorDict[NetService.errorDomain]?.intValue)
            return true
        }
        if failed { log("[tritonkit] Bonjour: publication failed (code \(snapshot.errorCode ?? 0)); HTTP service is independent") }
    }

    func netServiceDidStop(_ sender: NetService) {
        lock.withLock {
            guard service === sender else { return }
            service = nil
            if status.state != "failed" || stopRequested { setState("stopped") }
        }
    }

    private func pumpRunLoop() {
        if !RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) {
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    private func setState(_ value: String) {
        status = TKDiscoveryStatus(wanted: wanted, state: value, serviceType: serviceType)
    }
}
