import Foundation
import ImageIO

/// Check the encoded container and metadata without decoding a full pixel buffer.
/// This is not validation of arbitrary compressed pixel data or every chunk CRC;
/// the image decoder remains responsible for that. Only adb's PNG output uses it.
func validatedAndroidFramebufferPNG(_ data: Data) -> Data? {
    guard data.count <= 16 * 1024 * 1024,
          data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
          hasCompleteFramebufferPNGContainer(data) else { return nil }
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options),
          let type = CGImageSourceGetType(source), type as String == "public.png",
          CGImageSourceGetCount(source) == 1,
          CGImageSourceGetStatus(source) == .statusComplete,
          CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0 else { return nil }
    return data
}

private func hasCompleteFramebufferPNGContainer(_ data: Data) -> Bool {
    data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
        guard bytes.count >= 8 + 25 + 12 + 12 else { return false }
        func word(at offset: Int) -> UInt32 {
            UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 |
                UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        }
        var offset = 8
        var hasImageData = false
        while offset <= bytes.count - 12 {
            let length = Int(word(at: offset))
            guard length <= bytes.count - offset - 12 else { return false }
            let type = word(at: offset + 4)
            if offset == 8 {
                guard type == 0x49484452, length == 13 else { return false } // IHDR
            } else if type == 0x49484452 {
                return false
            }
            if type == 0x49444154, length > 0 { hasImageData = true } // IDAT
            if type == 0x49454e44 { // IEND must terminate this complete frame.
                return length == 0 && hasImageData && offset + 12 == bytes.count
            }
            offset += length + 12
        }
        return false
    }
}
