import ArgumentParser
import CoreFoundation
import Foundation
import TritonKitShared

func printPreferences(
    simulator: String,
    bundleID: String,
    key: String?,
    outputFormat: ClientOutputFormat
) throws {
    do {
        let plistPath = try resolveHostPreferencesPath(simulator: simulator, bundleID: bundleID)
        let existing = FileManager.default.fileExists(atPath: plistPath) ? try Data(contentsOf: URL(fileURLWithPath: plistPath)) : nil
        guard existing != nil || key != nil else { throw HostCommandRunError.missingPreferences(path: plistPath) }
        let data = try existing ?? PropertyListSerialization.data(fromPropertyList: [:], format: .binary, options: 0)
        let snapshot = try TKHostPreferencesSnapshot(bundleID: bundleID, plistPath: plistPath, data: data)
        let presence = try key.map { try hostPreferencePresence(existingData: existing, key: $0) }
        let value = presence?.value
        let output = HostPreferencesOutput(
            ok: true,
            action: key == nil ? "app.prefs.dump" : "app.prefs.get",
            simulatorUDID: simulator,
            bundleID: bundleID,
            plistPath: plistPath,
            key: key,
            value: value,
            valuePlistType: value?.kind,
            preferences: key == nil ? snapshot.preferences : nil,
            preferencesPlistTypes: key == nil ? snapshot.preferences.mapValues(\.kind) : nil
        )
        switch outputFormat {
        case .json:
            if let presence { print(try encodeJSON(HostPreferencesPresenceOutput(output: output, present: presence.present))) }
            else { print(try encodeJSON(output)) }
        case .text:
            if let key {
                if presence?.present == false { print("\(key)=<missing> present=false") }
                else { print("\(key)=\(value.map(renderPreferenceValue) ?? "")") }
            } else {
                for (key, value) in snapshot.preferences.sorted(by: { $0.key < $1.key }) {
                    print("\(key)=\(renderPreferenceValue(value))")
                }
            }
        }
    } catch {
        try failHostCommand(error, outputFormat: outputFormat)
    }
}

func setPreference(
    simulator: String,
    bundleID: String,
    key: String,
    value: String?,
    type: HostPreferenceSetType = .json,
    base64: String? = nil,
    hex: String? = nil,
    relaunch: Bool = false,
    outputFormat: ClientOutputFormat
) throws {
    do {
        let newValue = try parseHostPreferenceSetValue(type: type, value: value, base64: base64, hex: hex)
        let plistPath = try resolveHostPreferencesPath(simulator: simulator, bundleID: bundleID)
        let existingData = FileManager.default.fileExists(atPath: plistPath) ? try Data(contentsOf: URL(fileURLWithPath: plistPath)) : nil
        let update = try updatingPreferencePlistData(
            existingData: existingData,
            bundleID: bundleID,
            plistPath: plistPath,
            key: key,
            newValue: newValue
        )
        try ensureParentDirectory(for: plistPath)
        try update.data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
        guard try Data(contentsOf: URL(fileURLWithPath: plistPath)) == update.data else { throw RuntimeError("Preference disk readback failed.") }
        let delivery = performHostPreferencesRelaunch(simulator: simulator, bundleID: bundleID, requested: relaunch)
        let output = HostPreferencesSetOutput(
            ok: true,
            action: "app.prefs.set",
            simulatorUDID: simulator,
            bundleID: bundleID,
            plistPath: plistPath,
            key: key,
            previousValue: update.previousValue,
            newValue: update.newValue,
            previousPlistType: update.previousPlistType,
            newPlistType: update.newPlistType,
            restartAdvice: "Terminate and relaunch the app if it reads this preference only at startup."
        )
        switch outputFormat {
        case .json:
            print(try encodeJSON(HostPreferencesWriteOutput(output: output, relaunch: delivery)))
        case .text:
            print("\(key)=\(renderPreferenceValue(update.newValue))")
            if !delivery.ok { print("Disk write verified; relaunch \(delivery.status).") }
        }
        if !delivery.ok { throw ExitCode.failure }
    } catch let exit as ExitCode { throw exit }
    catch { try failHostCommand(error, outputFormat: outputFormat) }
}

func parseHostPreferenceSetValue(
    type: HostPreferenceSetType,
    value: String?,
    base64: String?,
    hex: String?
) throws -> TKHostPreferenceValue {
    switch type {
    case .json:
        guard base64 == nil, hex == nil else {
            throw RuntimeError("--base64 and --hex require --type data.")
        }
        guard let value else {
            throw RuntimeError("prefs set requires a JSON value unless --type data is used.")
        }
        return try parseHostPreferenceJSONValue(value)
    case .data:
        guard value == nil else {
            throw RuntimeError("--type data does not accept a positional JSON value; use --base64 or --hex.")
        }
        let payloads = [base64, hex].compactMap { $0 }
        guard payloads.count == 1 else {
            throw RuntimeError("--type data requires exactly one of --base64 or --hex.")
        }
        if let base64 {
            guard let data = Data(base64Encoded: base64) else {
                throw RuntimeError("Invalid base64 data preference value.")
            }
            return .data(data.base64EncodedString())
        }
        let data = try parseHexData(hex ?? "")
        return .data(data.base64EncodedString())
    }
}

func parseHostPreferenceJSONValue(_ value: String) throws -> TKHostPreferenceValue {
    let data = Data(value.utf8)
    let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    return try hostPreferenceValue(fromJSONObject: object)
}

func updatingPreferencePlistData(
    existingData: Data?,
    bundleID: String,
    plistPath: String,
    key: String,
    newValue: TKHostPreferenceValue
) throws -> HostPreferencePlistUpdateResult {
    let dictionary: [String: Any]
    if let existingData {
        let object = try PropertyListSerialization.propertyList(from: existingData, options: [], format: nil)
        guard let existing = object as? [String: Any] else {
            throw TKHostPreferencesError.invalidRoot
        }
        dictionary = existing
    } else {
        dictionary = [:]
    }

    let snapshotData = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
    let previousValue = try hostPreferencePresence(existingData: snapshotData, key: key).value
    var updated = dictionary
    updated[key] = try propertyListObject(fromPreferenceValue: newValue)
    let data = try PropertyListSerialization.data(fromPropertyList: updated, format: .binary, options: 0)
    return HostPreferencePlistUpdateResult(
        data: data,
        previousValue: previousValue,
        newValue: newValue,
        previousPlistType: previousValue?.kind,
        newPlistType: newValue.kind
    )
}

private func parseHexData(_ value: String) throws -> Data {
    var hex = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
        hex.removeFirst(2)
    }
    hex.removeAll { $0.isWhitespace }
    guard !hex.isEmpty, hex.count.isMultiple(of: 2) else {
        throw RuntimeError("Invalid hex data preference value.")
    }

    var bytes = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        let pair = String(hex[index..<next])
        guard let byte = UInt8(pair, radix: 16) else {
            throw RuntimeError("Invalid hex data preference value.")
        }
        bytes.append(byte)
        index = next
    }
    return bytes
}

private func hostPreferenceValue(fromJSONObject object: Any, allowData: Bool = false, depth: Int = 0) throws -> TKHostPreferenceValue {
    guard depth <= 32 else { throw RuntimeError("Preference nesting exceeds 32 levels.") }
    switch object {
    case let value as String:
        return .string(value)
    case let value as NSNumber:
        if CFGetTypeID(value) == CFBooleanGetTypeID() { return .bool(value.boolValue) }
        let doubleValue = value.doubleValue
        guard doubleValue.isFinite else { throw RuntimeError("Preference numbers must be finite.") }
        if floor(doubleValue) == doubleValue {
            if let exact = Int(value.stringValue) { return .int(exact) }
            guard doubleValue >= Double(Int.min), doubleValue < Double(Int.max) else { throw RuntimeError("Preference integer is outside the supported range.") }
            return .int(Int(doubleValue))
        }
        return .double(doubleValue)
    case let value as [Any]:
        return .array(try value.map { try hostPreferenceValue(fromJSONObject: $0, allowData: allowData, depth: depth + 1) })
    case let value as [String: Any]:
        return .dictionary(try value.mapValues { try hostPreferenceValue(fromJSONObject: $0, allowData: allowData, depth: depth + 1) })
    case let value as Data where allowData:
        return .data(value.base64EncodedString())
    case _ as NSNull:
        throw RuntimeError("Property list preferences do not support null. Use a string, number, bool, array, or object.")
    default:
        throw RuntimeError("Unsupported preference value type.")
    }
}

private func propertyListObject(fromPreferenceValue value: TKHostPreferenceValue) throws -> Any {
    switch value {
    case .string(let value):
        return value
    case .bool(let value):
        return value
    case .int(let value):
        return value
    case .double(let value):
        return value
    case .array(let values):
        return try values.map(propertyListObject(fromPreferenceValue:))
    case .dictionary(let values):
        return try values.mapValues(propertyListObject(fromPreferenceValue:))
    case .data(let value):
        guard let data = Data(base64Encoded: value) else {
            throw RuntimeError("Invalid base64 data preference value.")
        }
        return data
    }
}

func renderPreferenceValue(_ value: TKHostPreferenceValue) -> String {
    switch value {
    case .string(let value):
        value
    case .bool(let value):
        value ? "true" : "false"
    case .int(let value):
        "\(value)"
    case .double(let value):
        "\(value)"
    case .array(let values):
        "[" + values.map(renderPreferenceValue).joined(separator: ",") + "]"
    case .dictionary(let values):
        "{" + values.keys.sorted().map { "\($0):\(renderPreferenceValue(values[$0]!))" }.joined(separator: ",") + "}"
    case .data(let value):
        value
    }
}


func hostPreferencePresence(existingData: Data?, key: String) throws -> (present: Bool, value: TKHostPreferenceValue?) {
    guard let existingData else { return (false, nil) }
    guard let dictionary = try PropertyListSerialization.propertyList(from: existingData, options: [], format: nil) as? [String: Any] else { throw TKHostPreferencesError.invalidRoot }
    guard let raw = dictionary[key] else { return (false, nil) }
    // Presence is about the actual plist key; unsupported values are errors, never "missing".
    return (true, try hostPreferenceValue(fromJSONObject: raw, allowData: true))
}

func parseHostPreferenceImport(data: Data, format: HostPreferencesImportFormat, keys: [String]) throws -> [String: TKHostPreferenceValue] {
    guard data.count <= 1_048_576, !keys.isEmpty, keys.count <= 256,
          keys.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 1024 && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }) else {
        throw RuntimeError("Import requires 1...256 explicit --key selections and input up to 1MiB.")
    }
    let object: Any
    switch format {
    case .json: object = try JSONSerialization.jsonObject(with: data)
    case .plist: object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }
    guard let dictionary = object as? [String: Any] else { throw TKHostPreferencesError.invalidRoot }
    // Validate every input entry before selecting keys: a malformed ignored entry is still invalid input.
    let all = try dictionary.mapValues { try hostPreferenceValue(fromJSONObject: $0, allowData: format == .plist) }
    var selected: [String: TKHostPreferenceValue] = [:]
    for key in Set(keys).sorted() {
        guard let value = all[key] else { throw RuntimeError("Import selected key is absent from input.") }
        selected[key] = value
    }
    return selected
}

func mergingHostPreferenceImport(existingData: Data?, values: [String: TKHostPreferenceValue]) throws -> Data {
    var updated = existingData
    for key in values.keys.sorted() {
        updated = try updatingPreferencePlistData(existingData: updated, bundleID: "import", plistPath: "", key: key, newValue: values[key]!).data
    }
    guard let updated else { throw RuntimeError("Import has no selected values.") }
    return updated
}

func performHostPreferencesRelaunch(
    simulator: String, bundleID: String, requested: Bool,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) }
) -> HostPreferencesRelaunchReceipt {
    guard requested else { return .init(requested: false, status: "not-requested") }
    do {
        let result = try runner(TKSimctlCommand.terminateApp(udid: simulator, bundleID: bundleID))
        guard result.exitCode == 0 else { return .init(requested: true, status: "terminate-failed") }
    } catch { return .init(requested: true, status: "terminate-failed") }
    do {
        let result = try runner(TKSimctlCommand.launchApp(udid: simulator, bundleID: bundleID))
        guard result.exitCode == 0 else { return .init(requested: true, status: "launch-failed") }
    } catch { return .init(requested: true, status: "launch-failed") }
    return .init(requested: true, status: "launched")
}

/// Dependency-injected disk path and runner keep fixtures independent of devices.
func importHostPreferences(
    simulator: String, bundleID: String, inputData: Data, inputFormat: HostPreferencesImportFormat,
    keys: [String], relaunch: Bool = false,
    pathProvider: () throws -> String,
    runner: (TKHostCommand) throws -> HostProcessResult = { try runHostCommand($0) }
) throws -> HostPreferencesImportOutput {
    let values = try parseHostPreferenceImport(data: inputData, format: inputFormat, keys: keys)
    let path = try pathProvider()
    let existing = FileManager.default.fileExists(atPath: path) ? try Data(contentsOf: URL(fileURLWithPath: path)) : nil
    let data = try mergingHostPreferenceImport(existingData: existing, values: values)
    try ensureParentDirectory(for: path)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    guard try Data(contentsOf: URL(fileURLWithPath: path)) == data else { throw RuntimeError("Preference disk readback failed.") }
    let delivery = performHostPreferencesRelaunch(simulator: simulator, bundleID: bundleID, requested: relaunch, runner: runner)
    return HostPreferencesImportOutput(ok: delivery.ok, simulatorUDID: simulator, bundleID: bundleID,
        importedKeys: values.keys.sorted(), importedPlistTypes: values.mapValues(\.kind), diskWriteVerified: true, relaunch: delivery)
}

func resolveHostPreferencesPath(simulator: String, bundleID: String) throws -> String {
    guard !bundleID.isEmpty, bundleID.utf8.count <= 255,
          bundleID.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0) }), bundleID != ".", bundleID != ".." else { throw RuntimeError("Invalid bundle identifier for app preferences.") }
    let result = try runHostCommand(TKSimctlCommand.appContainer(udid: simulator, bundleID: bundleID, kind: .data))
    let container = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    guard result.exitCode == 0, !result.stdoutTruncated, container.hasPrefix("/"),
          !container.contains("\n"), !container.contains("\0") else { throw RuntimeError("Unable to resolve app data container.") }
    return TKHostPreferencesSnapshot.plistPath(dataContainer: container, bundleID: bundleID)
}
