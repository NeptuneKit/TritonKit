import ArgumentParser
import Foundation

/// The mirror is a terminal client of existing CLI actions, never another device executor.
enum DeviceMirrorProtocol: String, ExpressibleByArgument {
    case auto, kitty, iterm2
    static func detect(environment: [String: String]) -> Self? {
        if environment["TERM_PROGRAM"] == "ghostty" || environment["TERM"] == "xterm-kitty" || environment["KITTY_WINDOW_ID"] != nil { return .kitty }
        if environment["TERM_PROGRAM"] == "iTerm.app" { return .iterm2 }
        return nil
    }
}
struct DeviceMirrorOutput: Encodable {
    let ok: Bool
    let action: String
    let platform: String
    let mode: String
    let frames: Int
    let images: [String]
    let sourceWidth: Int
    let sourceHeight: Int
    let businessReadinessVerified: Bool
}
struct DeviceMirrorPoint: Equatable { let x: Int; let y: Int }
struct DeviceMirrorLayout {
    let sourceWidth: Int
    let sourceHeight: Int
    let columns: Int
    let rows: Int
    init(sourceWidth: Int, sourceHeight: Int, terminalColumns: Int, terminalRows: Int, cellWidth: Int, cellHeight: Int) {
        self.sourceWidth = sourceWidth; self.sourceHeight = sourceHeight
        let availableColumns = max(1, terminalColumns)
        let availableRows = max(1, terminalRows - 2)
        let scale = min(Double(availableColumns * max(1, cellWidth)) / Double(max(1, sourceWidth)), Double(availableRows * max(1, cellHeight)) / Double(max(1, sourceHeight)))
        columns = max(1, min(availableColumns, Int(Double(sourceWidth) * scale / Double(max(1, cellWidth)))))
        rows = max(1, min(availableRows, Int(Double(sourceHeight) * scale / Double(max(1, cellHeight)))))
    }
    func point(column: Int, row: Int) -> DeviceMirrorPoint? {
        guard (1...columns).contains(column), (1...rows).contains(row) else { return nil }
        return DeviceMirrorPoint(x: (column - 1) * sourceWidth / columns, y: (row - 1) * sourceHeight / rows)
    }
}
enum DeviceMirrorInput: Equatable {
    case click(column: Int, row: Int), text(String), press(String), quit
}
struct DeviceMirrorInputDecoder {
    private var pending = Data()
    mutating func feed(_ bytes: Data) -> [DeviceMirrorInput] {
        pending.append(bytes)
        if pending.count > 8192 { pending.removeAll(); return [] }
        var actions: [DeviceMirrorInput] = []
        while !pending.isEmpty {
            let bytes = [UInt8](pending)
            if bytes[0] == 27 {
                // SGR mouse events may arrive across reads; consume only complete sequences.
                let prefix: [UInt8] = [27, 91, 60]
                if bytes.count < 3 && prefix.starts(with: bytes) { break }
                if bytes.starts(with: prefix) {
                    guard let end = bytes.dropFirst(3).firstIndex(where: { $0 == 77 || $0 == 109 }) else { break }
                    let parts = String(decoding: bytes[3..<end], as: UTF8.self).split(separator: ";").compactMap { Int($0) }
                    if bytes[end] == 77, parts.count == 3, parts[0] == 0, parts[1] > 0, parts[2] > 0 { actions.append(.click(column: parts[1], row: parts[2])) }
                    pending.removeFirst(end + 1); continue
                }
                if bytes.count == 1 { break }
                if bytes[1] == 91 || bytes[1] == 79 {
                    guard let end = bytes.dropFirst(2).firstIndex(where: { (64...126).contains($0) }) else { break }
                    pending.removeFirst(end + 1); continue
                }
                pending.removeFirst(); continue
            }
            let action: DeviceMirrorInput?
            switch bytes[0] {
            case 3, 4: action = .quit
            case 8: action = .press("home")
            case 2: action = .press("back")
            case 1: action = .press("app-switch")
            case 13: action = .text("\n")
            default: action = nil
            }
            if let action { actions.append(action); pending.removeFirst(); continue }
            if bytes[0] < 32 || bytes[0] == 127 { pending.removeFirst(); continue }
            let length = bytes[0] < 128 ? 1 : bytes[0] < 224 ? 2 : bytes[0] < 240 ? 3 : 4
            guard bytes.count >= length else { break }
            if let text = String(data: pending.prefix(length), encoding: .utf8) { actions.append(.text(text)); pending.removeFirst(length) }
            else { pending.removeFirst() }
        }
        // Coalesce adjacent printable scalars into one text action.
        return actions.reduce(into: []) { result, action in
            if case .text(let text) = action, case .text(let previous)? = result.last { result[result.count - 1] = .text(previous + text) }
            else { result.append(action) }
        }
    }
}
func deviceMirrorSafeText(_ value: String) -> String {
    String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }).prefix(160).description
}
let deviceMirrorTerminalCleanup = "\u{1b}_Ga=d,d=I,i=31,q=2\u{1b}\\\u{1b}[?1000l\u{1b}[?1006l\u{1b}[?25h\u{1b}[?1049l"
func deviceMirrorRenderPNG(_ data: Data, protocolKind: DeviceMirrorProtocol, columns: Int, rows: Int) -> String {
    let base64 = data.base64EncodedString()
    if protocolKind == .iterm2 { return "\u{1b}]1337;File=inline=1;width=\(columns);height=\(rows);preserveAspectRatio=1:\(base64)\u{7}" }
    let bytes = Array(base64.utf8)
    var result = ""
    for offset in stride(from: 0, to: bytes.count, by: 4096) {
        let end = min(offset + 4096, bytes.count)
        let header = offset == 0 ? "a=T,f=100,t=d,i=31,c=\(columns),r=\(rows),q=2," : ""
        result += "\u{1b}_G\(header)m=\(end < bytes.count ? 1 : 0);\(String(decoding: bytes[offset..<end], as: UTF8.self))\u{1b}\\"
    }
    return result
}
