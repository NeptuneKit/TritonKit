import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import IOSurface
import Testing
@testable import TritonKitCLI

@Suite("Native framebuffer primary identity", .serialized)
struct SimulatorFramebufferSelectionTests {
    let primaryID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let secondaryID = UUID(uuidString: "22222222-2222-3333-4444-555555555555")!

    @Test func largerSecondaryCannotReplaceTheBoundPrimary() throws {
        let primary = try FramebufferDescriptorFixture(id: primaryID.uuidString, width: 12, height: 26)
        let secondary = try FramebufferDescriptorFixture(id: secondaryID.uuidString, width: 64, height: 36)
        let session = FramebufferSession(udid: "fixture")
        defer { session.stop() }
        #expect(session.start(simDevice: FramebufferDeviceFixture([secondary, primary]), primaryDisplayUUID: primaryID))
        let image = try waitForImage(session)
        #expect(image.width == 12)
        #expect(image.height == 26)
        #expect(primary.registrations == 1)
        #expect(secondary.registrations == 0)
    }

    @Test func dynamicObjectGetterForwardingRemainsSupported() throws {
        let primary = try FramebufferDescriptorFixture(id: primaryID.uuidString, width: 12, height: 26)
        primary.screenProperties = FramebufferForwardingFixture(primary.screenProperties)
        #expect(class_getInstanceMethod(type(of: primary.screenProperties), NSSelectorFromString("uniqueId")) == nil)
        let proxy = FramebufferForwardingFixture(primary)
        #expect(class_getInstanceMethod(type(of: proxy), NSSelectorFromString("screenProperties")) == nil)
        let session = FramebufferSession(udid: "fixture")
        defer { session.stop() }
        #expect(session.start(simDevice: FramebufferDeviceFixture([proxy]), primaryDisplayUUID: primaryID))
        let image = try waitForImage(session)
        #expect(image.width == 12 && image.height == 26)
    }

    @Test func untrustedOrAmbiguousIdentityNeverRegistersCapture() throws {
        let valid = try FramebufferDescriptorFixture(id: primaryID.uuidString)
        let secondary = try FramebufferDescriptorFixture(id: secondaryID.uuidString)
        let missing = try FramebufferDescriptorFixture(id: nil)
        let invalid = try FramebufferDescriptorFixture(id: "not-a-uuid")
        let duplicate = try FramebufferDescriptorFixture(id: primaryID.uuidString.lowercased())
        for (bound, candidates) in [
            (nil, [valid]), (primaryID, [secondary]), (primaryID, [missing]),
            (primaryID, [invalid]), (primaryID, [valid, duplicate]), (primaryID, [valid, missing]),
        ] as [(UUID?, [NSObject])] {
            let session = FramebufferSession(udid: "fixture")
            defer { session.stop() }
            #expect(!session.start(simDevice: FramebufferDeviceFixture(candidates), primaryDisplayUUID: bound))
            #expect(session.getLatestFrameWithVersion() == nil)
        }
        #expect(valid.registrations == 0)
        #expect(secondary.registrations == 0)
    }

    @Test func missingPrimarySurfaceNeverFallsBackToSecondary() throws {
        let primary = try FramebufferDescriptorFixture(id: primaryID.uuidString)
        let secondary = try FramebufferDescriptorFixture(id: secondaryID.uuidString, width: 64, height: 36)
        primary.framebufferSurface = nil
        let session = FramebufferSession(udid: "fixture")
        defer { session.stop() }
        #expect(session.start(simDevice: FramebufferDeviceFixture([primary, secondary]), primaryDisplayUUID: primaryID))
        Thread.sleep(forTimeInterval: 0.15)
        #expect(session.getLatestFrameWithVersion() == nil)
        #expect(primary.registrations == 1)
        #expect(secondary.registrations == 0)
    }

    @Test("A published frame is cleared if its bound identity or surface disappears", arguments: ["identity", "surface"])
    func lostPrimaryClearsThePublishedFrame(_ loss: String) throws {
        let primary = try FramebufferDescriptorFixture(id: primaryID.uuidString)
        let secondary = try FramebufferDescriptorFixture(id: secondaryID.uuidString, width: 64, height: 36)
        let session = FramebufferSession(udid: "fixture")
        defer { session.stop() }
        #expect(session.start(simDevice: FramebufferDeviceFixture([primary, secondary]), primaryDisplayUUID: primaryID))
        let image = try waitForImage(session)
        #expect(image.width == 12 && image.height == 26)
        if loss == "identity" {
            primary.screenProperties = FramebufferScreenPropertiesFixture(secondaryID.uuidString)
            primary.publishPropertiesChange()
        } else {
            primary.framebufferSurface = nil
            primary.publishSurfaceChange()
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while session.getLatestFrameWithVersion() != nil, ContinuousClock.now < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #expect(session.getLatestFrameWithVersion() == nil)
        #expect(secondary.registrations == 0)
    }

    private func waitForImage(_ session: FramebufferSession) throws -> CGImage {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if let (data, _) = session.getLatestFrameWithVersion(),
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) { return image }
            Thread.sleep(forTimeInterval: 0.01)
        }
        throw FramebufferFixtureError.noFrame
    }
}

private enum FramebufferFixtureError: Error { case surfaceUnavailable, noFrame }

private final class FramebufferScreenPropertiesFixture: NSObject {
    @objc let uniqueId: NSString?
    init(_ id: String?) { uniqueId = id.map { $0 as NSString } }
}

private final class FramebufferDescriptorFixture: NSObject {
    @objc var screenProperties: NSObject
    @objc var framebufferSurface: AnyObject?
    private(set) var registrations = 0
    private var propertiesChanged: (@convention(block) () -> Void)?
    private var surfacesChanged: (@convention(block) () -> Void)?

    init(id: String?, width: Int = 12, height: Int = 26) throws {
        screenProperties = FramebufferScreenPropertiesFixture(id)
        let row = IOSurfaceAlignProperty(kIOSurfaceBytesPerRow, width * 4)
        let properties: [CFString: Any] = [
            kIOSurfaceWidth: width, kIOSurfaceHeight: height,
            kIOSurfaceBytesPerElement: 4, kIOSurfaceBytesPerRow: row,
            kIOSurfaceAllocSize: IOSurfaceAlignProperty(kIOSurfaceAllocSize, row * height),
            kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA,
        ]
        guard let surface = IOSurfaceCreate(properties as CFDictionary) else { throw FramebufferFixtureError.surfaceUnavailable }
        framebufferSurface = surface as AnyObject
    }

    @objc(registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:)
    func register(_ uuid: AnyObject, queue: AnyObject, frame: AnyObject, surfaces: AnyObject, properties: AnyObject) {
        registrations += 1
        propertiesChanged = unsafeBitCast(properties, to: (@convention(block) () -> Void).self)
        surfacesChanged = unsafeBitCast(surfaces, to: (@convention(block) () -> Void).self)
    }
    func publishPropertiesChange() { propertiesChanged?() }
    func publishSurfaceChange() { surfacesChanged?() }
    @objc(unregisterScreenCallbacksWithUUID:)
    func unregister(_ uuid: AnyObject) { propertiesChanged = nil; surfacesChanged = nil }
}

private final class FramebufferPortFixture: NSObject {
    @objc let portIdentifier = "com.apple.framebuffer.display"
    @objc let descriptor: NSObject
    init(_ descriptor: NSObject) { self.descriptor = descriptor }
}
private final class FramebufferIOFixture: NSObject {
    @objc let deviceIOPorts: NSArray
    init(_ descriptors: [NSObject]) { deviceIOPorts = descriptors.map(FramebufferPortFixture.init) as NSArray }
    @objc func updateIOPorts() {}
}
private final class FramebufferDeviceFixture: NSObject {
    @objc let io: NSObject
    init(_ descriptors: [NSObject]) { io = FramebufferIOFixture(descriptors) }
}
private final class FramebufferForwardingFixture: NSObject {
    let backing: NSObject
    init(_ backing: NSObject) { self.backing = backing }
    override func responds(to selector: Selector!) -> Bool { backing.responds(to: selector) || super.responds(to: selector) }
    override func forwardingTarget(for selector: Selector!) -> Any? { backing.responds(to: selector) ? backing : super.forwardingTarget(for: selector) }
}
