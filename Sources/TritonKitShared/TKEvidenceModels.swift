import Foundation

public struct TKEvidenceManifest: Codable, Equatable {
    public let ok: Bool
    public let formatVersion: Int
    public let name: String?
    public let note: String?
    public let createdAt: String
    public let output: String
    public let artifacts: [TKEvidenceArtifact]
    public let primaryArtifact: TKEvidenceArtifactSummary?
    public let primaryArtifacts: [TKEvidenceArtifactSummary]
    public let skipped: [TKEvidenceSkippedArtifact]
    public let target: TKEvidenceTarget?
    public let cli: TKEvidenceCLI
    public let run: TKEvidenceRunManifest?

    public init(
        ok: Bool,
        formatVersion: Int = 1,
        name: String? = nil,
        note: String? = nil,
        createdAt: String,
        output: String,
        artifacts: [TKEvidenceArtifact],
        primaryArtifact: TKEvidenceArtifactSummary? = nil,
        primaryArtifacts: [TKEvidenceArtifactSummary]? = nil,
        skipped: [TKEvidenceSkippedArtifact] = [],
        target: TKEvidenceTarget? = nil,
        cli: TKEvidenceCLI,
        run: TKEvidenceRunManifest? = nil
    ) {
        self.ok = ok
        self.formatVersion = formatVersion
        self.name = name
        self.note = note
        self.createdAt = createdAt
        self.output = output
        self.artifacts = artifacts
        self.primaryArtifacts = primaryArtifacts ?? TKEvidenceArtifactSummary.defaultPrimaryArtifacts(from: artifacts.map(TKEvidenceArtifactSummary.init))
        self.primaryArtifact = primaryArtifact ?? self.primaryArtifacts.first
        self.skipped = skipped
        self.target = target
        self.cli = cli
        self.run = run
    }

    enum CodingKeys: String, CodingKey {
        case ok
        case formatVersion
        case name
        case note
        case createdAt
        case output
        case artifacts
        case primaryArtifact
        case primaryArtifacts
        case skipped
        case target
        case cli
        case run
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let artifacts = try container.decode([TKEvidenceArtifact].self, forKey: .artifacts)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.output = try container.decode(String.self, forKey: .output)
        self.artifacts = artifacts
        self.primaryArtifacts = try container.decodeIfPresent([TKEvidenceArtifactSummary].self, forKey: .primaryArtifacts)
            ?? TKEvidenceArtifactSummary.defaultPrimaryArtifacts(from: artifacts.map(TKEvidenceArtifactSummary.init))
        self.primaryArtifact = try container.decodeIfPresent(TKEvidenceArtifactSummary.self, forKey: .primaryArtifact)
            ?? self.primaryArtifacts.first
        self.skipped = try container.decodeIfPresent([TKEvidenceSkippedArtifact].self, forKey: .skipped) ?? []
        self.target = try container.decodeIfPresent(TKEvidenceTarget.self, forKey: .target)
        self.cli = try container.decode(TKEvidenceCLI.self, forKey: .cli)
        self.run = try container.decodeIfPresent(TKEvidenceRunManifest.self, forKey: .run)
    }
}

public struct TKEvidenceRunManifest: Codable, Equatable, Sendable {
    public let eventsPath: String
    public let metaPath: String
    public let screenshotPaths: [String]
    public let debugArtifactPaths: [String]
    public let eventCount: Int?
    public let status: TKEvidenceRunParseStatus?
    public let summary: TKEvidenceRunSummary?

    public init(
        eventsPath: String = "run/events.jsonl",
        metaPath: String = "run/meta.json",
        screenshotPaths: [String] = [],
        debugArtifactPaths: [String] = [],
        eventCount: Int? = nil,
        status: TKEvidenceRunParseStatus? = nil,
        summary: TKEvidenceRunSummary? = nil
    ) {
        self.eventsPath = eventsPath
        self.metaPath = metaPath
        self.screenshotPaths = screenshotPaths
        self.debugArtifactPaths = debugArtifactPaths
        self.eventCount = eventCount
        self.status = status
        self.summary = summary
    }
}

public struct TKEvidenceArtifact: Codable, Equatable {
    public let kind: String
    public let path: String
    public let contentType: String?
    public let bytes: Int?
    public let freshness: TKEvidenceFreshness?
    public let platform: String?
    public let riskLevel: String?
    public let policy: String?
    public let redactionStatus: String?
    public let sourceCommand: String?
    public let target: String?

    public init(
        kind: String,
        path: String,
        contentType: String? = nil,
        bytes: Int? = nil,
        freshness: TKEvidenceFreshness? = nil,
        platform: String? = nil,
        riskLevel: String? = nil,
        policy: String? = nil,
        redactionStatus: String? = nil,
        sourceCommand: String? = nil,
        target: String? = nil
    ) {
        self.kind = kind
        self.path = path
        self.contentType = contentType
        self.bytes = bytes
        self.freshness = freshness
        self.platform = platform
        self.riskLevel = riskLevel
        self.policy = policy
        self.redactionStatus = redactionStatus
        self.sourceCommand = sourceCommand
        self.target = target
    }
}

public struct TKEvidenceSkippedArtifact: Codable, Equatable {
    public let kind: String
    public let reason: String

    public init(kind: String, reason: String) {
        self.kind = kind
        self.reason = reason
    }
}

public struct TKEvidenceFreshness: Codable, Equatable {
    public let capturedAt: String
    public let source: String
    public let hierarchyCacheState: String?
    public let targetConnectionState: String?

    public init(
        capturedAt: String,
        source: String,
        hierarchyCacheState: String? = nil,
        targetConnectionState: String? = nil
    ) {
        self.capturedAt = capturedAt
        self.source = source
        self.hierarchyCacheState = hierarchyCacheState
        self.targetConnectionState = targetConnectionState
    }
}

public struct TKEvidenceTarget: Codable, Equatable {
    public let id: String
    public let connected: Bool
    public let appName: String?
    public let bundleIdentifier: String?
    public let deviceDescription: String?
    public let osDescription: String?
    public let identityState: String
    public let targetConnectionState: String?
    public let hierarchyCacheState: String?

    public init(
        id: String = TKLocalTargetID,
        connected: Bool,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        deviceDescription: String? = nil,
        osDescription: String? = nil,
        identityState: String,
        targetConnectionState: String? = nil,
        hierarchyCacheState: String? = nil
    ) {
        self.id = id
        self.connected = connected
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.deviceDescription = deviceDescription
        self.osDescription = osDescription
        self.identityState = identityState
        self.targetConnectionState = targetConnectionState
        self.hierarchyCacheState = hierarchyCacheState
    }
}

public struct TKEvidenceCLI: Codable, Equatable {
    public let version: String
    public let schemaVersion: Int

    public init(version: String, schemaVersion: Int = 1) {
        self.version = version
        self.schemaVersion = schemaVersion
    }
}

public struct TKEvidenceArtifactSummary: Codable, Equatable {
    public let kind: String
    public let path: String
    public let contentType: String?
    public let bytes: Int?
    public let platform: String?
    public let riskLevel: String?
    public let policy: String?
    public let redactionStatus: String?
    public let target: String?

    public init(
        kind: String,
        path: String,
        contentType: String? = nil,
        bytes: Int? = nil,
        platform: String? = nil,
        riskLevel: String? = nil,
        policy: String? = nil,
        redactionStatus: String? = nil,
        target: String? = nil
    ) {
        self.kind = kind
        self.path = path
        self.contentType = contentType
        self.bytes = bytes
        self.platform = platform
        self.riskLevel = riskLevel
        self.policy = policy
        self.redactionStatus = redactionStatus
        self.target = target
    }

    public init(_ artifact: TKEvidenceArtifact) {
        self.init(
            kind: artifact.kind,
            path: artifact.path,
            contentType: artifact.contentType,
            bytes: artifact.bytes,
            platform: artifact.platform,
            riskLevel: artifact.riskLevel,
            policy: artifact.policy,
            redactionStatus: artifact.redactionStatus,
            target: artifact.target
        )
    }

    static func defaultPrimaryArtifacts(from artifacts: [TKEvidenceArtifactSummary], limit: Int = 5) -> [TKEvidenceArtifactSummary] {
        let priorities: [String: Int] = [
            "real-device.diagnostics": 0,
            "host.app-action": 1,
            "runtime.snapshot": 2,
            "host.layout": 3,
            "screenshot": 4,
            "logs": 5,
            "build.summary": 6,
            "network-capture": 7,
            "network.proxy-session": 8,
            "xcode.action-summary": 9,
            "archive": 10,
            "geometry": 11,
            "ax": 12,
            "hierarchy": 13,
            "run.events": 14,
            "run.meta": 15,
            "status": 16,
            "list": 17,
            "version": 18,
            "host.defaults": 19,
            "host.simulators": 20,
            "xcode.status": 21,
            "xcode.discovery": 22,
            "xcode.defaults": 23,
        ]

        return artifacts.enumerated()
            .sorted { lhs, rhs in
                let lhsPriority = priorities[lhs.element.kind] ?? 100
                let rhsPriority = priorities[rhs.element.kind] ?? 100
                if lhsPriority == rhsPriority {
                    return lhs.offset < rhs.offset
                }
                return lhsPriority < rhsPriority
            }
            .prefix(limit)
            .map(\.element)
    }
}

public struct TKEvidenceSummaryResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let input: String
    public let profile: String
    public let createdAt: String
    public let name: String?
    public let note: String?
    public let output: String
    public let artifactCount: Int
    public let sensitiveArtifactCount: Int
    public let skippedCount: Int
    public let target: TKEvidenceTarget?
    public let cli: TKEvidenceCLI
    public let artifacts: [TKEvidenceArtifactSummary]
    public let primaryArtifact: TKEvidenceArtifactSummary?
    public let primaryArtifacts: [TKEvidenceArtifactSummary]
    public let skipped: [TKEvidenceSkippedArtifact]
    public let suggestedCommands: [String]

    public init(
        ok: Bool = true,
        action: String,
        input: String,
        profile: String,
        createdAt: String,
        name: String? = nil,
        note: String? = nil,
        output: String,
        artifactCount: Int,
        sensitiveArtifactCount: Int,
        skippedCount: Int,
        target: TKEvidenceTarget? = nil,
        cli: TKEvidenceCLI,
        artifacts: [TKEvidenceArtifactSummary],
        primaryArtifact: TKEvidenceArtifactSummary? = nil,
        primaryArtifacts: [TKEvidenceArtifactSummary]? = nil,
        skipped: [TKEvidenceSkippedArtifact],
        suggestedCommands: [String]
    ) {
        self.ok = ok
        self.action = action
        self.input = input
        self.profile = profile
        self.createdAt = createdAt
        self.name = name
        self.note = note
        self.output = output
        self.artifactCount = artifactCount
        self.sensitiveArtifactCount = sensitiveArtifactCount
        self.skippedCount = skippedCount
        self.target = target
        self.cli = cli
        self.artifacts = artifacts
        self.primaryArtifacts = primaryArtifacts ?? TKEvidenceArtifactSummary.defaultPrimaryArtifacts(from: artifacts)
        self.primaryArtifact = primaryArtifact ?? self.primaryArtifacts.first
        self.skipped = skipped
        self.suggestedCommands = suggestedCommands
    }

    enum CodingKeys: String, CodingKey {
        case ok
        case action
        case input
        case profile
        case createdAt
        case name
        case note
        case output
        case artifactCount
        case sensitiveArtifactCount
        case skippedCount
        case target
        case cli
        case artifacts
        case primaryArtifact
        case primaryArtifacts
        case skipped
        case suggestedCommands
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let artifacts = try container.decode([TKEvidenceArtifactSummary].self, forKey: .artifacts)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.action = try container.decode(String.self, forKey: .action)
        self.input = try container.decode(String.self, forKey: .input)
        self.profile = try container.decode(String.self, forKey: .profile)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.output = try container.decode(String.self, forKey: .output)
        self.artifactCount = try container.decode(Int.self, forKey: .artifactCount)
        self.sensitiveArtifactCount = try container.decode(Int.self, forKey: .sensitiveArtifactCount)
        self.skippedCount = try container.decode(Int.self, forKey: .skippedCount)
        self.target = try container.decodeIfPresent(TKEvidenceTarget.self, forKey: .target)
        self.cli = try container.decode(TKEvidenceCLI.self, forKey: .cli)
        self.artifacts = artifacts
        self.primaryArtifacts = try container.decodeIfPresent([TKEvidenceArtifactSummary].self, forKey: .primaryArtifacts)
            ?? TKEvidenceArtifactSummary.defaultPrimaryArtifacts(from: artifacts)
        self.primaryArtifact = try container.decodeIfPresent(TKEvidenceArtifactSummary.self, forKey: .primaryArtifact)
            ?? self.primaryArtifacts.first
        self.skipped = try container.decode([TKEvidenceSkippedArtifact].self, forKey: .skipped)
        self.suggestedCommands = try container.decodeIfPresent([String].self, forKey: .suggestedCommands) ?? []
    }
}

public struct TKEvidenceRedactionResponse: Codable, Equatable {
    public let ok: Bool
    public let action: String
    public let input: String
    public let output: String
    public let profile: String
    public let createdAt: String
    public let artifactCount: Int
    public let redactedArtifactCount: Int
    public let keptArtifactCount: Int
    public let manifest: TKEvidenceManifest
    public let redactedArtifacts: [TKEvidenceArtifactSummary]
    public let keptArtifacts: [TKEvidenceArtifactSummary]
    public let primaryArtifact: TKEvidenceArtifactSummary?
    public let primaryArtifacts: [TKEvidenceArtifactSummary]
    public let summaryPath: String
    public let suggestedCommands: [String]

    public init(
        ok: Bool = true,
        action: String,
        input: String,
        output: String,
        profile: String,
        createdAt: String,
        artifactCount: Int,
        redactedArtifactCount: Int,
        keptArtifactCount: Int,
        manifest: TKEvidenceManifest,
        redactedArtifacts: [TKEvidenceArtifactSummary],
        keptArtifacts: [TKEvidenceArtifactSummary],
        primaryArtifact: TKEvidenceArtifactSummary? = nil,
        primaryArtifacts: [TKEvidenceArtifactSummary]? = nil,
        summaryPath: String,
        suggestedCommands: [String] = []
    ) {
        self.ok = ok
        self.action = action
        self.input = input
        self.output = output
        self.profile = profile
        self.createdAt = createdAt
        self.artifactCount = artifactCount
        self.redactedArtifactCount = redactedArtifactCount
        self.keptArtifactCount = keptArtifactCount
        self.manifest = manifest
        self.redactedArtifacts = redactedArtifacts
        self.keptArtifacts = keptArtifacts
        self.primaryArtifacts = primaryArtifacts ?? manifest.primaryArtifacts
        self.primaryArtifact = primaryArtifact ?? self.primaryArtifacts.first
        self.summaryPath = summaryPath
        self.suggestedCommands = suggestedCommands
    }

    enum CodingKeys: String, CodingKey {
        case ok
        case action
        case input
        case output
        case profile
        case createdAt
        case artifactCount
        case redactedArtifactCount
        case keptArtifactCount
        case manifest
        case redactedArtifacts
        case keptArtifacts
        case primaryArtifact
        case primaryArtifacts
        case summaryPath
        case suggestedCommands
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let manifest = try container.decode(TKEvidenceManifest.self, forKey: .manifest)
        self.ok = try container.decode(Bool.self, forKey: .ok)
        self.action = try container.decode(String.self, forKey: .action)
        self.input = try container.decode(String.self, forKey: .input)
        self.output = try container.decode(String.self, forKey: .output)
        self.profile = try container.decode(String.self, forKey: .profile)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.artifactCount = try container.decode(Int.self, forKey: .artifactCount)
        self.redactedArtifactCount = try container.decode(Int.self, forKey: .redactedArtifactCount)
        self.keptArtifactCount = try container.decode(Int.self, forKey: .keptArtifactCount)
        self.manifest = manifest
        self.redactedArtifacts = try container.decode([TKEvidenceArtifactSummary].self, forKey: .redactedArtifacts)
        self.keptArtifacts = try container.decode([TKEvidenceArtifactSummary].self, forKey: .keptArtifacts)
        self.primaryArtifacts = try container.decodeIfPresent([TKEvidenceArtifactSummary].self, forKey: .primaryArtifacts)
            ?? manifest.primaryArtifacts
        self.primaryArtifact = try container.decodeIfPresent(TKEvidenceArtifactSummary.self, forKey: .primaryArtifact)
            ?? self.primaryArtifacts.first
        self.summaryPath = try container.decode(String.self, forKey: .summaryPath)
        self.suggestedCommands = try container.decodeIfPresent([String].self, forKey: .suggestedCommands) ?? []
    }
}
