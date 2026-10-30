import CoreFoundation
import Foundation

struct SimulatorFramebufferPixelSize: Equatable {
    let width: Int
    let height: Int
}

struct SimulatorFramebufferDisplayBinding: Equatable {
    let displayUniqueID: UUID
    // Used to verify captured image geometry, never to select a descriptor.
    let nativePixelSize: SimulatorFramebufferPixelSize?
}

enum SimulatorFramebufferDisplayResolution: Equatable {
    case binding(SimulatorFramebufferDisplayBinding)
    case unknown(IOSSimulatorDisplayUnknownReason)
}

func classifySimulatorFramebufferDisplayBinding(data: Data, target: String, exitCode: Int32, expectedArguments: [String]) -> SimulatorFramebufferDisplayResolution {
    let primary: IOSSimulatorDisplay
    switch classifyIOSSimulatorDisplayTopology(data: data, target: target, exitCode: exitCode, expectedArguments: expectedArguments) {
    case .primary(let display): primary = display
    case .unknown(let reason): return .unknown(reason)
    }
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let info = root["info"] as? [String: Any], info["error"] == nil, info["errors"] == nil,
          let result = root["result"] as? [String: Any],
          let displays = result["displays"] as? [[String: Any]],
          displays.allSatisfy({ $0["error"] == nil && $0["errors"] == nil }),
          let display = displays.first(where: { ($0["displayId"] as? NSNumber)?.stringValue == primary.id }),
          let text = display["uniqueId"] as? String, let uniqueID = UUID(uuidString: text) else {
        return .unknown(.invalidResponse)
    }
    if let identity = result["deviceIdentifier"] {
        guard let value = identity as? String, UUID(uuidString: value) == UUID(uuidString: target) else { return .unknown(.identityMismatch) }
    }
    var size: SimulatorFramebufferPixelSize?
    if let values = display["nativeSize"] as? [NSNumber], values.count == 2,
       values.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() }),
       let width = Int(values[0].stringValue), let height = Int(values[1].stringValue),
       width > 0, height > 0, width <= 16_384, height <= 16_384 {
        size = .init(width: width, height: height)
    }
    return .binding(.init(displayUniqueID: uniqueID, nativePixelSize: size))
}

func probeSimulatorFramebufferDisplayBinding(target: String, environment: [String: String]) -> SimulatorFramebufferDisplayResolution {
    switch queryIOSSimulatorDisplaySnapshot(target: target, environment: environment) {
    case .unknown(let reason): return .unknown(reason)
    case .response(let data, let exitCode, let arguments):
        return classifySimulatorFramebufferDisplayBinding(data: data, target: target, exitCode: exitCode, expectedArguments: arguments)
    }
}

/// These object getters are declared by SimScreen and SimScreenProperties.
/// ROCK proxies dynamically forward them; a local class method/IMP is not required.
func simulatorFramebufferDescriptorUUID(_ descriptor: NSObject) -> UUID? {
    let propertiesSelector = NSSelectorFromString("screenProperties")
    let uniqueIDSelector = NSSelectorFromString("uniqueId")
    guard descriptor.responds(to: propertiesSelector),
          let properties = descriptor.perform(propertiesSelector)?.takeUnretainedValue() as? NSObject,
          properties.responds(to: uniqueIDSelector),
          let value = properties.perform(uniqueIDSelector)?.takeUnretainedValue() else { return nil }
    if let text = value as? String { return UUID(uuidString: text) }
    return value as? UUID
}

func selectSimulatorPrimaryFramebufferDescriptor(_ descriptors: [NSObject], primaryDisplayUUID: UUID?) -> NSObject? {
    guard let primaryDisplayUUID, !descriptors.isEmpty else { return nil }
    var seen = Set<UUID>()
    var selected: NSObject?
    for descriptor in descriptors {
        guard let uniqueID = simulatorFramebufferDescriptorUUID(descriptor), seen.insert(uniqueID).inserted else { return nil }
        if uniqueID == primaryDisplayUUID { selected = descriptor }
    }
    return selected
}
