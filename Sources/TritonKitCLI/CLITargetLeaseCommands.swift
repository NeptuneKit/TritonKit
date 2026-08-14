import ArgumentParser
import Foundation
import TritonKitShared

// MARK: - Target Lease CLI Commands
//
// `triton target lease acquire|status|release|takeover` manages the opt-in,
// auditable reservation of an iOS Simulator target. The `triton serve`
// process owns the lease store; these commands are thin HTTP clients.

struct TargetLease: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lease",
        abstract: "Acquire, inspect, release, or take over an opt-in iOS Simulator target lease",
        subcommands: [TargetLeaseAcquire.self, TargetLeaseStatus.self, TargetLeaseRelease.self, TargetLeaseTakeover.self]
    )
}

/// Resolve a simulator selector to the concrete lease key both sides agree
/// on. When the caller already resolved the selector (e.g. through
/// `resolveHostDeviceSelection`), pass the concrete target so `booted` /
/// `current` / aliases key on the real UDID; otherwise fall back to the
/// normalized selector string.
func targetLeaseKeyFromSelector(_ selector: String, resolvedTarget: String? = nil) -> String {
    if let resolvedTarget, !resolvedTarget.isEmpty {
        return TKNormalizeTargetLeaseKey(resolvedTarget)
    }
    return TKNormalizeTargetLeaseKey(selector)
}

private func resolvedTargetLeaseKey(_ selector: String) -> String {
    if let selection = try? resolveHostDeviceSelection(
        request: HostDeviceSelectionRequest(device: selector, platform: .ios, ready: false),
        hdc: "hdc"
    ) {
        return targetLeaseKeyFromSelector(selector, resolvedTarget: selection.target.target)
    }
    return targetLeaseKeyFromSelector(selector)
}

struct TargetLeaseAcquire: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "acquire", abstract: "Acquire a bounded-TTL lease for an iOS Simulator target")

    @Option(help: "Simulator target selector: UDID, sim:<udid>, booted, or current") var target: String
    @Option(help: "Opaque caller-provided owner label for local diagnostics") var owner: String
    @Option(name: .customLong("ttl"), help: "Lease TTL in seconds (\(TKTargetLeaseMinTTLSeconds)...\(TKTargetLeaseMaxTTLSeconds), default \(TKTargetLeaseDefaultTTLSeconds))") var ttlSeconds: Int?
    @Option(name: .customLong("readonly-observation-allowed"), help: "Whether read-only observation is permitted while the lease is held (default true)") var readonlyObservationAllowed: Bool?
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let client = TritonKitHTTPClient(host: host, port: port)
            let response: TKTargetLeaseAcquireResponse = try await client.postJSON(
                "/v1/target-leases/acquire",
                body: TKTargetLeaseAcquireRequest(
                    target: resolvedTargetLeaseKey(target),
                    owner: owner,
                    ttlSeconds: ttlSeconds,
                    readonlyObservationAllowed: readonlyObservationAllowed
                )
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("status: \(response.status)")
                print("target: \(response.target)")
                if let lease = response.lease {
                    print("lease: \(lease.id)")
                    print("owner: \(lease.owner)")
                    print("expiresAt: \(lease.expiresAt)")
                }
                if let previousOwner = response.previousOwner {
                    print("previousOwner: \(previousOwner)")
                }
            }
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct TargetLeaseStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show the current lease state for an iOS Simulator target")

    @Option(help: "Simulator target selector: UDID, sim:<udid>, booted, or current") var target: String
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let client = TritonKitHTTPClient(host: host, port: port)
            let key = resolvedTargetLeaseKey(target)
            let response: TKTargetLeaseStatusResponse = try await client.getJSON(
                "/v1/target-leases/status",
                queryItems: [URLQueryItem(name: "target", value: key)]
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("status: \(response.status)")
                print("target: \(response.target)")
                if let lease = response.lease {
                    print("lease: \(lease.id)")
                    print("owner: \(lease.owner)")
                    print("expiresAt: \(lease.expiresAt)")
                }
            }
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct TargetLeaseRelease: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "release", abstract: "Release a held lease for an iOS Simulator target")

    @Option(help: "Simulator target selector: UDID, sim:<udid>, booted, or current") var target: String
    @Option(name: .customLong("lease"), help: "Lease token returned by acquire/takeover") var leaseID: String
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let client = TritonKitHTTPClient(host: host, port: port)
            let response: TKTargetLeaseReleaseResponse = try await client.postJSON(
                "/v1/target-leases/release",
                body: TKTargetLeaseReleaseRequest(
                    target: resolvedTargetLeaseKey(target),
                    leaseID: leaseID
                )
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("released: \(response.released)")
                print("status: \(response.status)")
                print("target: \(response.target)")
                if let lease = response.lease {
                    print("lease: \(lease.id)")
                    print("owner: \(lease.owner)")
                }
            }
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}

struct TargetLeaseTakeover: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "takeover", abstract: "Explicitly take over a lease held by another owner (requires --confirm)")

    @Option(help: "Simulator target selector: UDID, sim:<udid>, booted, or current") var target: String
    @Option(help: "Opaque caller-provided owner label for local diagnostics") var owner: String
    @Option(name: .customLong("ttl"), help: "Lease TTL in seconds (\(TKTargetLeaseMinTTLSeconds)...\(TKTargetLeaseMaxTTLSeconds), default \(TKTargetLeaseDefaultTTLSeconds))") var ttlSeconds: Int?
    @Option(name: .customLong("readonly-observation-allowed"), help: "Whether read-only observation is permitted while the lease is held (default true)") var readonlyObservationAllowed: Bool?
    @Flag(help: "Explicitly confirm the takeover that displaces the current owner") var confirm = false
    @Option(help: "Server host") var host: String = "127.0.0.1"
    @Option(help: "Server port") var port: Int = 19421
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "Output format: text or json") var format: ClientOutputFormat = .json

    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let client = TritonKitHTTPClient(host: host, port: port)
            let response: TKTargetLeaseAcquireResponse = try await client.postJSON(
                "/v1/target-leases/takeover",
                body: TKTargetLeaseTakeoverRequest(
                    target: resolvedTargetLeaseKey(target),
                    owner: owner,
                    ttlSeconds: ttlSeconds,
                    readonlyObservationAllowed: readonlyObservationAllowed,
                    confirm: confirm
                )
            )
            switch outputFormat {
            case .json:
                print(try encodeJSON(response))
            case .text:
                print("status: \(response.status)")
                print("target: \(response.target)")
                if let lease = response.lease {
                    print("lease: \(lease.id)")
                    print("owner: \(lease.owner)")
                    print("expiresAt: \(lease.expiresAt)")
                }
                if let previousOwner = response.previousOwner {
                    print("previousOwner: \(previousOwner)")
                }
            }
        } catch {
            if error is ExitCode { throw error }
            try failHostCommand(error, outputFormat: outputFormat)
        }
    }
}
