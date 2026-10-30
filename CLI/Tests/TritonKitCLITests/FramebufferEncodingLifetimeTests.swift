import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import IOSurface
import Testing
@testable import TritonKitCLI

@Suite(.serialized)
struct FramebufferEncodingLifetimeTests {
    @Test func publishedJPEGSurvivesEncodingPoolAndPreservesDimensions() throws {
        let surface = try makeEncodingLifetimeSurface(width: 64, height: 128)
        let session = FramebufferSession(udid: "encoding-lifetime-fixture")
        defer { session.stop() }
        session.processFrame(surface: surface)
        let (data, version) = try #require(session.getLatestFrameWithVersion())
        // Decode after processFrame's autorelease pool has already drained.
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 64)
        #expect(image.height == 128)
        #expect(version == 1)
    }

    @Test func identicalSurfaceDoesNotPublishAnotherVersion() throws {
        let surface = try makeEncodingLifetimeSurface(width: 64, height: 128)
        let session = FramebufferSession(udid: "same-frame-fixture")
        defer { session.stop() }
        session.processFrame(surface: surface)
        let first = try #require(session.getLatestFrameWithVersion())
        for _ in 0..<5 { session.processFrame(surface: surface) }
        let latest = try #require(session.getLatestFrameWithVersion())
        #expect(latest.0 == first.0)
        #expect(latest.1 == first.1)
    }

    @Test func stoppedSessionClearsFrameAndRejectsLateEncoding() throws {
        let surface = try makeEncodingLifetimeSurface(width: 64, height: 128)
        let session = FramebufferSession(udid: "stopped-encoding-fixture")
        session.processFrame(surface: surface)
        let retained = try #require(session.getLatestFrameWithVersion()).0
        session.stop()
        #expect(session.getLatestFrameWithVersion() == nil)
        session.processFrame(surface: surface)
        #expect(session.getLatestFrameWithVersion() == nil)
        // Existing consumers still own a valid Data even after the producer stops.
        let source = try #require(CGImageSourceCreateWithData(retained as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 64 && image.height == 128)
    }
}

private func makeEncodingLifetimeSurface(width: Int, height: Int) throws -> IOSurfaceRef {
    let rowBytes = IOSurfaceAlignProperty(kIOSurfaceBytesPerRow, width * 4)
    let properties: [CFString: Any] = [
        kIOSurfaceWidth: width, kIOSurfaceHeight: height,
        kIOSurfaceBytesPerElement: 4, kIOSurfaceBytesPerRow: rowBytes,
        kIOSurfaceAllocSize: IOSurfaceAlignProperty(kIOSurfaceAllocSize, rowBytes * height),
        kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA,
    ]
    let surface = try #require(IOSurfaceCreate(properties as CFDictionary))
    try #require(IOSurfaceLock(surface, [], nil) == 0)
    defer { _ = IOSurfaceUnlock(surface, [], nil) }
    let canvas = try #require(CGContext(
        data: IOSurfaceGetBaseAddress(surface), width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: rowBytes, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    ))
    canvas.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
    canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return surface
}
