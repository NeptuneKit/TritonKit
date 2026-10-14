import Foundation

struct TKAppMapPage {
    let offset: Int
    let limit: Int
    init(offset: Int = 0, limit: Int = 100) throws {
        guard offset >= 0, (1...1000).contains(limit) else { throw TKAppMapError.invalidPage }
        self.offset = offset
        self.limit = limit
    }
    func range(totalCount: Int) -> Range<Int> {
        let start = min(offset, totalCount)
        return start..<(start + min(limit, totalCount - start))
    }
    func nextOffset(totalCount: Int) -> Int? {
        let end = range(totalCount: totalCount).upperBound
        return end < totalCount ? end : nil
    }
}
