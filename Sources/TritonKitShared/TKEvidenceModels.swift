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
        self.skipped = skipped
        self.suggestedCommands = suggestedCommands
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
    public let summaryPath: String

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
        summaryPath: String
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
        self.summaryPath = summaryPath
    }
}
