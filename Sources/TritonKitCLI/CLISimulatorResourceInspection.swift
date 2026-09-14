import Foundation

struct SimulatorResourceInspection {
    let read: (String) throws -> SimulatorResourceOverrideState

    func status(udid: String) throws -> [String: Any] {
        let state = try read(udid)
        let disabled = Set(state.overrides.filter(\.value).map(\.key))
        let managed = disabled.intersection(SimulatorResourceCatalog.managedLabels)
        return ["ok": true, "action": "resource.status", "simulatorUDID": udid,
                "managedDisabled": managed.count,
                "managedTotal": SimulatorResourceCatalog.managedLabels.count,
                "disabledLabels": managed.sorted(),
                "source": "simctl-launchctl-print-disabled"]
    }

    func doctor(udid: String, requires: [String]) throws -> [String: Any] {
        let features = try SimulatorResourceCatalog.resolveFeatures(requires)
        guard !features.isEmpty else { throw SimulatorResourceInspectionError.missingRequirements }
        let state = try read(udid)
        let results: [[String: Any]] = features.map { feature in
            let disabled = feature.labels.filter { state.overrides[$0] == true }.sorted()
            return ["id": feature.id, "ok": disabled.isEmpty, "disabledLabels": disabled]
        }
        return ["ok": results.allSatisfy { $0["ok"] as? Bool == true },
                "action": "resource.doctor", "simulatorUDID": udid,
                "features": results, "verificationBoundary": "service-overrides-only"]
    }
}

enum SimulatorResourceInspectionError: Error {
    case missingRequirements
}
