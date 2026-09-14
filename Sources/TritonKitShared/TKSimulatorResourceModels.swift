import Foundation

public enum TKSimulatorResourceCategory: String, Codable, CaseIterable, Sendable { case core, networking, push, store, search, web, media, location, diagnostics }
public enum TKSimulatorResourceFeature: String, Codable, CaseIterable, Sendable { case push, storeKit, universalLinks, spotlight, webViews, location, media }

public struct TKSimulatorResourceProfile: Codable, Equatable, Sendable {
    public var id: String
    public var version: Int
    public var disabledCategories: Set<TKSimulatorResourceCategory>
    public init(id: String, version: Int = 1, disabledCategories: Set<TKSimulatorResourceCategory> = []) { self.id=id; self.version=version; self.disabledCategories=disabledCategories }
    public func validate() throws {
        guard !id.isEmpty, version > 0 else { throw ValidationError.invalidProfile }
    }
    public enum ValidationError: Error, Equatable { case invalidProfile }
}

public struct TKSimulatorResourceStatus: Codable, Equatable, Sendable {
    public var udid: String
    public var runtime: String
    public var profileID: String?
    public var enabled: Bool
    public var disabledCategories: Set<TKSimulatorResourceCategory>
    public init(udid: String, runtime: String, profileID: String? = nil, enabled: Bool = false, disabledCategories: Set<TKSimulatorResourceCategory> = []) { self.udid=udid; self.runtime=runtime; self.profileID=profileID; self.enabled=enabled; self.disabledCategories=disabledCategories }
}

public struct TKSimulatorRuntimeCompatibility: Codable, Equatable, Sendable {
    public var runtime: String
    public var supported: Bool
    public var persistentOverride: Bool
    public var reason: String?
    public init(runtime: String, supported: Bool, persistentOverride: Bool, reason: String? = nil) { self.runtime=runtime; self.supported=supported; self.persistentOverride=persistentOverride; self.reason=reason }
}

public struct TKSimulatorResourceMeasurement: Codable, Equatable, Sendable {
    public var udid: String
    public var memoryBytes: Int64
    public var processCount: Int
    public var diskBytes: Int64?
    public init(udid: String, memoryBytes: Int64, processCount: Int, diskBytes: Int64? = nil) { self.udid=udid; self.memoryBytes=memoryBytes; self.processCount=processCount; self.diskBytes=diskBytes }
}

public struct TKSimulatorResourceCapabilityImpact: Codable, Equatable, Sendable {
    public var feature: TKSimulatorResourceFeature
    public var affectedCategories: Set<TKSimulatorResourceCategory>
    public init(feature: TKSimulatorResourceFeature, affectedCategories: Set<TKSimulatorResourceCategory>) { self.feature=feature; self.affectedCategories=affectedCategories }
}
