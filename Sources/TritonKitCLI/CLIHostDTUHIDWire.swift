// DTUHID wire/endpoint reference: heoblitz/Loupe 180c60584867500b93b43ca6c8b556995bf8be7b
// and facebook/idb c793afad2a31092628f7013cf1aa96f266c85024 (MIT).
// Copyright (c) 2026 heoblitz; Copyright (c) Meta Platforms, Inc. and affiliates.
// Complete notices are shipped in Resources/native-hid.
import Foundation
import XPC

/// Only the pre-mutation, booted-device lookup can authorize legacy selection.
enum DTUHIDLookup {
    static let service = "com.apple.coredevice.feature.remote.hid.digitizer"
    static func unsupported(methodAvailable: Bool, port: UInt32, error: NSError?) -> Bool {
        !methodAvailable || (port == 0 && error?.domain == "com.apple.CoreSimulator.SimError" && error?.code == 405)
    }
}

/// Deliberately no public key/button input surface. The keyboard message is a
/// separate no-event barrier, never a touch with isBarrier set.
enum DTUHIDMessage: Equatable {
    case barrier
    case touch(x: Double, y: Double, phase: UInt64)

    var xpc: xpc_object_t {
        let message = xpc_dictionary_create(nil, nil, 0)
        let payload = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "featureIdentifier", DTUHIDLookup.service)
        switch self {
        case .barrier:
            xpc_dictionary_set_string(message, "messageType", "IndigoKeyboardButtonEvent")
            xpc_dictionary_set_bool(message, "isBarrier", true)
            xpc_dictionary_set_uint64(payload, "usageCode", 0)
            xpc_dictionary_set_uint64(payload, "state", 2)
        case let .touch(x, y, phase):
            xpc_dictionary_set_string(message, "messageType", "IndigoDigitizerEvent")
            xpc_dictionary_set_bool(message, "isBarrier", false)
            let point = xpc_dictionary_create(nil, nil, 0)
            xpc_dictionary_set_double(point, "x", x)
            xpc_dictionary_set_double(point, "y", y)
            xpc_dictionary_set_value(payload, "pointOne", point)
            xpc_dictionary_set_uint64(payload, "eventType", phase)
            xpc_dictionary_set_uint64(payload, "edge", 0)
            // Admitted only by the helper's unchanged primary portrait guards.
            xpc_dictionary_set_uint64(payload, "target", 0)
        }
        xpc_dictionary_set_value(message, "payload", payload)
        return message
    }
}
