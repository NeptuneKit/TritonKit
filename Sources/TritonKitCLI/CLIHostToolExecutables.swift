import Foundation

func findAdbExecutable(environment env: [String: String] = ProcessInfo.processInfo.environment, fileExists: (String) -> Bool = isUsableHostToolExecutable) -> String {
    let home = env["HOME"] ?? ""
    if !home.isEmpty {
        let path1 = "\(home)/Library/Android/sdk/platform-tools/adb"
        if fileExists(path1) {
            return path1
        }
    }
    if let pathVar = env["PATH"] {
        for dir in pathVar.split(separator: ":") {
            let fullPath = "\(dir)/adb"
            if fileExists(fullPath) {
                return fullPath
            }
        }
    }
    return "adb"
}

func findHdcExecutable(environment env: [String: String] = ProcessInfo.processInfo.environment, fileExists: (String) -> Bool = isUsableHostToolExecutable) -> String {
    let home = env["HOME"] ?? ""
    if !home.isEmpty {
        let path1 = "\(home)/harmonyOS-command-line-tools/bin/hdc"
        if fileExists(path1) {
            return path1
        }
        let path2 = "\(home)/Library/Huawei/Sdk/openharmony/12/toolchains/hdc"
        if fileExists(path2) {
            return path2
        }
        let path3 = "\(home)/Library/Huawei/Sdk/openharmony/11/toolchains/hdc"
        if fileExists(path3) {
            return path3
        }
    }
    if let pathVar = env["PATH"] {
        for dir in pathVar.split(separator: ":") {
            let fullPath = "\(dir)/hdc"
            if fileExists(fullPath) {
                return fullPath
            }
        }
    }
    return "hdc"
}

// MARK: - Client Commands

private func isUsableHostToolExecutable(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        && !isDirectory.boolValue
        && FileManager.default.isExecutableFile(atPath: path)
}
