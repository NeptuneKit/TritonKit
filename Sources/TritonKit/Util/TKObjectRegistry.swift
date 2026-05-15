import Foundation

public final class TKObjectRegistry {
    public static let shared = TKObjectRegistry()

    private var objects: [ObjectIdentifier: UInt] = [:]
    private var reverse: [UInt: WeakBox] = [:]
    private var nextOid: UInt = 1
    private let lock = NSLock()

    private init() {}

    public func register(_ object: AnyObject) -> UInt {
        lock.lock(); defer { lock.unlock() }
        let id = ObjectIdentifier(object)
        if let existing = objects[id] { return existing }
        let oid = nextOid
        nextOid += 1
        objects[id] = oid
        reverse[oid] = WeakBox(value: object)
        return oid
    }

    public func object(for oid: UInt) -> AnyObject? {
        lock.lock(); defer { lock.unlock() }
        return reverse[oid]?.value
    }
}

private final class WeakBox {
    weak var value: AnyObject?
    init(value: AnyObject) { self.value = value }
}
