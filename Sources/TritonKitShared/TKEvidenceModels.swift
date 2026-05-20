import Foundation

public struct TKEvidenceManifest: Codable, Equatable {
    public let ok: Bool
    public let formatVersion: Int
    public let name: String?
    public let note: String?
    public let createdAt: String
    public let output: String
    public let artifacts: [TKEvidenceArtifact]
    public let skipped: [TKEvidenceSkippedArtifact]
    public let target: TKEvidenceTarget?
    public let cli: TKEvidenceCLI

    public init(
        ok: Bool,
        formatVersion: Int = 1,
        name: String? = nil,
        note: String? = nil,
        createdAt: String,
        output: String,
        artifacts: [TKEvidenceArtifact],
        skipped: [TKEvidenceSkippedArtifact] = [],
        target: TKEvidenceTarget? = nil,
        cli: TKEvidenceCLI
    ) {
        self.ok = ok
        self.formatVersion = formatVersion
        self.name = name
        self.note = note
        self.createdAt = createdAt
        self.output = output
        self.artifacts = artifacts
        self.skipped = skipped
        self.target = target
        self.cli = cli
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
