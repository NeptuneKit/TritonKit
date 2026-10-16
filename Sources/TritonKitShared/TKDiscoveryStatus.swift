import Foundation

/// Bonjour publication only. Neither a published record nor TCP readiness authenticates a peer.
public struct TKDiscoveryStatus: Codable, Equatable, Sendable {
    public let wanted: Bool
    public let state: String
    public let serviceType: String
    public let identityVerified: Bool
    public let errorCode: Int?
    public let errorDomain: Int?

    public init(wanted: Bool, state: String, serviceType: String = "_tritonkit-server._tcp.", errorCode: Int? = nil, errorDomain: Int? = nil) {
        self.wanted = wanted
        self.state = state
        self.serviceType = serviceType
        self.identityVerified = false
        self.errorCode = errorCode
        self.errorDomain = errorDomain
    }

    enum CodingKeys: String, CodingKey {
        case wanted, state, serviceType, identityVerified, errorCode, errorDomain
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            wanted: try values.decode(Bool.self, forKey: .wanted),
            state: try values.decode(String.self, forKey: .state),
            serviceType: try values.decode(String.self, forKey: .serviceType),
            errorCode: try values.decodeIfPresent(Int.self, forKey: .errorCode),
            errorDomain: try values.decodeIfPresent(Int.self, forKey: .errorDomain)
        )
        // A remote assertion is never authentication evidence. This protocol has
        // no identity-verification mechanism, even if a peer sends true here.
    }

}
