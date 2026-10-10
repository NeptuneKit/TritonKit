import Foundation

// Preflight byte/depth budget only: strict bound root always has this prefix and a 36-byte ASCII UUID.
// The placeholder is never opened/queried and is not identity/mount evidence. Fresh actual binding remains mandatory.
func validateDeviceFSSelectionBudget(homeDirectory: String, relativeDirectory: String?) throws {
    let shape = homeDirectory + "/Library/Developer/CoreDevice/DeviceFS/device-00000000-0000-0000-0000-000000000000.localized"
    do { _ = try validatedDeviceFSComponents(root: shape, relativeDirectory: relativeDirectory) }
    catch { throw HostDeviceSelectionError.parameterConflict("Combined DeviceFS directory selection exceeds local depth/path bounds; no query or directory IO started.") }
}
