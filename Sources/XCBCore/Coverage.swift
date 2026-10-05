import Foundation

/// The subset of `xcrun xccov view --report --json` that xcb reports on.
struct CoverageReport: Decodable {
    struct Target: Decodable {
        let name: String
        let lineCoverage: Double
        let coveredLines: Int
        let executableLines: Int
        let files: [File]
    }

    struct File: Decodable {
        let name: String
        let lineCoverage: Double
        let coveredLines: Int
        let executableLines: Int
    }

    let targets: [Target]

    /// Targets with executable lines (excludes empty stubs/headers) whose name contains
    /// `filter`. Falls back to all such targets if the filter matches nothing.
    func targets(matching filter: String) -> (targets: [Target], filterMatched: Bool) {
        let all = targets.filter { $0.executableLines > 0 }
        guard !filter.isEmpty else { return (all, true) }
        let matching = all.filter { $0.name.contains(filter) }
        return matching.isEmpty ? (all, false) : (matching, true)
    }
}

enum CoverageFormatter {
    static func percent(_ coverage: Double) -> String {
        String(format: "%.4f", coverage * 100)
    }

    static func summary(_ report: CoverageReport, xcresultPath: String, modified: Date?, filter: String) -> [String] {
        let (targets, filterMatched) = report.targets(matching: filter)
        var out: [String] = []
        if !filterMatched {
            out.append("\(yellow)⚠ No targets matching '\(filter)', showing all\(reset)")
        }
        out += [rule, "\(bold)📊 CODE COVERAGE REPORT\(reset)", rule, ""]
        out.append("\(cyan)📦 xcresult:\(reset) \(basename(xcresultPath))")
        if let modified {
            out.append("\(cyan)📅 Modified:\(reset) \(format(modified, "yyyy-MM-dd HH:mm:ss"))")
        }
        out.append("")

        for target in targets {
            let color = target.lineCoverage < 0.6 ? red : target.lineCoverage < 0.8 ? yellow : green
            out += [
                "\(bold)Target:\(reset) \(target.name)",
                "  \(bold)Line Coverage:\(reset)    \(color)\(percent(target.lineCoverage))%\(reset)",
                "  \(bold)Covered Lines:\(reset)    \(target.coveredLines) / \(target.executableLines)",
                "  \(bold)Files:\(reset)            \(target.files.count)",
                "",
            ]
        }
        out.append(rule)
        return out
    }

    static func detailed(_ report: CoverageReport, filter: String) -> [String] {
        let files = report.targets(matching: filter).targets
            .flatMap(\.files)
            .sorted { $0.lineCoverage > $1.lineCoverage }

        var out = ["", "\(bold)📁 File-Level Coverage:\(reset)", ""]
        out.append("\(bold)Top 10 Files (Best Coverage):\(reset)")
        for file in files.prefix(10) {
            out.append("  \(green)✓\(reset) \(basename(file.name))")
            out.append("    \(percent(file.lineCoverage))%  (\(file.coveredLines)/\(file.executableLines) lines)")
        }

        out += ["", "\(bold)Bottom 10 Files (Need Attention):\(reset)"]
        for file in files.suffix(10).reversed() {
            let color = file.lineCoverage < 0.3 ? red : yellow
            out.append("  \(color)⚠\(reset) \(basename(file.name))")
            out.append("    \(percent(file.lineCoverage))%  (\(file.coveredLines)/\(file.executableLines) lines)")
        }
        out.append("")
        return out
    }
}
