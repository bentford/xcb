import Foundation
import Testing
@testable import XCBCore

@Suite struct CoverageTests {
    static let json = """
        {"targets": [
          {"name": "MyApp.app", "lineCoverage": 0.85, "coveredLines": 85, "executableLines": 100,
           "files": [
             {"name": "Good.swift", "lineCoverage": 0.95, "coveredLines": 19, "executableLines": 20},
             {"name": "Okay.swift", "lineCoverage": 0.5, "coveredLines": 10, "executableLines": 20}
           ]},
          {"name": "MyKit.framework", "lineCoverage": 0.5, "coveredLines": 5, "executableLines": 10,
           "files": [
             {"name": "Bad.swift", "lineCoverage": 0.1, "coveredLines": 1, "executableLines": 10}
           ]},
          {"name": "Empty.framework", "lineCoverage": 0, "coveredLines": 0, "executableLines": 0, "files": []}
        ]}
        """

    let report: CoverageReport

    init() throws {
        report = try JSONDecoder().decode(CoverageReport.self, from: Data(Self.json.utf8))
    }

    func plain(_ lines: [String]) -> String {
        lines.joined(separator: "\n").replacingOccurrences(of: #"\x{1B}\[[0-9;]*m"#, with: "", options: .regularExpression)
    }

    @Test func formatsPercentWithFourDecimals() {
        #expect(CoverageFormatter.percent(0.85) == "85.0000")
        #expect(CoverageFormatter.percent(0.123456) == "12.3456")
    }

    @Test func excludesTargetsWithoutExecutableLines() {
        #expect(report.targets(matching: "").targets.map(\.name) == ["MyApp.app", "MyKit.framework"])
    }

    @Test func filtersTargetsByName() {
        let (targets, matched) = report.targets(matching: "Kit")
        #expect(matched)
        #expect(targets.map(\.name) == ["MyKit.framework"])
    }

    @Test func unmatchedFilterFallsBackToAllTargets() {
        let (targets, matched) = report.targets(matching: "Nope")
        #expect(!matched)
        #expect(targets.count == 2)

        let summary = plain(CoverageFormatter.summary(report, xcresultPath: "/tmp/X.xcresult", modified: nil, filter: "Nope"))
        #expect(summary.hasPrefix("⚠ No targets matching 'Nope', showing all"))
    }

    @Test func summaryListsEachTarget() {
        let summary = plain(CoverageFormatter.summary(report, xcresultPath: "/tmp/MyApp-Coverage.xcresult", modified: nil, filter: ""))
        #expect(summary.contains("📦 xcresult: MyApp-Coverage.xcresult"))
        #expect(summary.contains("Target: MyApp.app\n  Line Coverage:    85.0000%\n  Covered Lines:    85 / 100\n  Files:            2"))
        #expect(summary.contains("Target: MyKit.framework"))
        #expect(!summary.contains("Empty.framework"))
    }

    @Test func summaryColorsByThreshold() {
        let lines = CoverageFormatter.summary(report, xcresultPath: "x", modified: nil, filter: "")
        #expect(lines.contains { $0.contains("\(green)85.0000%") })
        #expect(lines.contains { $0.contains("\(red)50.0000%") })
    }

    @Test func detailedOrdersBestFirstAndWorstFirst() {
        let detailed = plain(CoverageFormatter.detailed(report, filter: ""))
        let top = detailed.components(separatedBy: "Bottom 10")[0]
        let bottom = detailed.components(separatedBy: "Bottom 10")[1]
        #expect(top.range(of: "Good.swift")!.lowerBound < top.range(of: "Bad.swift")!.lowerBound)
        #expect(bottom.range(of: "Bad.swift")!.lowerBound < bottom.range(of: "Good.swift")!.lowerBound)
        #expect(detailed.contains("10.0000%  (1/10 lines)"))
    }
}
