import Testing
@testable import LooseEnds

@Suite("Process cache") struct ProcessCacheTests {
    @Test("Builds once, then returns the same instance without building again")
    func buildsOnce() {
        let cache = ProcessCache<Int>()
        var buildCount = 0

        let first = cache.value { buildCount += 1; return 42 }
        let second = cache.value { buildCount += 1; return 99 }

        #expect(first == 42)
        #expect(second == 42)
        #expect(buildCount == 1)
    }
}
