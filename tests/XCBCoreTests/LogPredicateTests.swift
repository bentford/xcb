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

    @Test func escapesQuestionMarkInWildcards() {
        let predicate = LogPredicate.make(subsystem: "com.example.app", categories: ["Cache?*", "Auth?"])
        #expect(predicate == #"subsystem == "com.example.app" AND (category LIKE "Cache\\?*" OR category == "Auth?")"#)
    }

    @Test func escapesBackslashInWildcards() {
        let predicate = LogPredicate.make(subsystem: "com.example.app", categories: [#"Foo\Bar*"#, #"A\?*"#, #"Foo\Bar"#])
        #expect(predicate == #"subsystem == "com.example.app" AND (category LIKE "Foo\\\\Bar*" OR category LIKE "A\\\\\\?*" OR category == "Foo\\Bar")"#)
    }

    @Test func escapesQuotesAndBackslashes() {
        let predicate = LogPredicate.make(subsystem: #"com."app"\x"#, categories: [])
        #expect(predicate == #"subsystem == "com.\"app\"\\x""#)
    }
}
