import Foundation

func testRecorderCompiledContractRef(caseURL: URL) throws -> TKTestRecorderReplayContractRef? {
    let contractURL = caseURL.appendingPathComponent("compiled-contract.json")
    guard FileManager.default.fileExists(atPath: contractURL.path) else {
        return nil
    }
    let data = try Data(contentsOf: contractURL)
    return TKTestRecorderReplayContractRef(
        path: "compiled-contract.json",
        byteCount: data.count,
        digestAlgorithm: "fnv1a64",
        digest: fnv1a64Hex(data)
    )
}

func fnv1a64Hex(_ data: Data) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return String(format: "%016llx", hash)
}
