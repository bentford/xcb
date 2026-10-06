import Testing
@testable import XCBCore

@Suite struct LogPredicateTests {
    @Test func filtersBySubsystemOnly() {
        #expect(LogPredicate.make(subsystem: "com.example.app", categories: []) == #"subsystem == "com.example.app""#)
    }

    @Test func combinesCategoriesWithOr() {
        let predicate = LogPredicate.make(subsystem: "com.example.app", categories: ["Networking", "Auth"])
        #expect(predicate == #"subsystem == "com.example.app" AND (category == "Networking" OR category == "Auth")"#)
    }

    @Test func usesLikeForWildcards() {
        let predicate = LogPredicate.make(subsystem: "com.example.app", categories: ["Net*", "*work*", "Auth"])
        #expect(predicate == #"subsystem == "com.example.app" AND (category LIKE "Net*" OR category LIKE "*work*" OR category == "Auth")"#)
    }

    @Test func escapesQuotesAndBackslashes() {
        let predicate = LogPredicate.make(subsystem: #"com."app"\x"#, categories: [])
        #expect(predicate == #"subsystem == "com.\"app\"\\x""#)
    }
}
