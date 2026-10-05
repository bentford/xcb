import Testing
@testable import XCBCore

@Suite struct ErrorSummaryTests {
    @Test func extractsSwiftTestingFailures() {
        let failures = ErrorSummary.testFailureLines(in: """
            note: Build complete!
            ◇ Test run started.
            ◇ Suite MyTests started.
            ◇ Test myPassingTest() started.
            ✔ Test myPassingTest() passed after 0.001 seconds.
            ◇ Test myFailingTest() started.
            ✘ Test myFailingTest() recorded an issue at MyTests.swift:42:9: Expectation failed: (a → 1) == (2)
            ✘ Test myFailingTest() failed after 0.010 seconds with 1 issue.
            ✘ Suite MyTests failed after 0.011 seconds with 1 issue.
            ✘ Test run with 2 tests failed after 0.011 seconds with 1 issue.
            """)
        #expect(failures.count == 4)
        #expect(failures[0].contains("recorded an issue at MyTests.swift:42:9"))
        #expect(failures.contains { $0.contains("Suite MyTests failed") })
        #expect(!failures.contains { $0.contains("myPassingTest") || $0.contains("Build complete") })
    }

    @Test func extractsXCTestFailures() {
        let failures = ErrorSummary.testFailureLines(in: """
            note: Build complete!
            Test Case '-[MyTests testSomething]' started.
            /path/to/MyTests.swift:42: error: -[MyTests testSomething] : XCTAssertEqual failed: ("foo") is not equal to ("bar")
            Test Case '-[MyTests testSomething]' failed (0.001 seconds).
            """)
        #expect(failures.count == 1)
        #expect(failures[0].contains("XCTAssertEqual failed"))
    }

    @Test func noFailuresWhenTestsPass() {
        #expect(ErrorSummary.testFailureLines(in: """
            note: Build complete!
            ◇ Test run started.
            ✔ Test myPassingTest() passed after 0.001 seconds.
            """).isEmpty)
    }

    @Test func capsAtFiftyLines() {
        let log = (1...80).map { "✘ Test t\($0)() failed" }.joined(separator: "\n")
        #expect(ErrorSummary.testFailureLines(in: log).count == 50)
    }

    @Test func dropsBlankLines() {
        #expect(ErrorSummary.nonBlankLines("\n  \nerror: one\n\t\nwarning: two\n") == ["error: one", "warning: two"])
    }
}
