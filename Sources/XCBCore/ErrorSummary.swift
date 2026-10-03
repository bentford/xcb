import Foundation

/// Post-build summary of warnings, errors, and (optionally) test failures, formatted by xcbeautify.
enum ErrorSummary {
    /// Failure lines from a raw build log, capped at 50.
    /// ✘ = Swift Testing failures; ": error: -[" = XCTest assertion failures
    static func testFailureLines(in log: String) -> [String] {
        lines(log)
            .filter { $0.contains("✘ ") || $0.contains(": error: -[") }
            .prefix(50)
            .map(String.init)
    }

    static func nonBlankLines(_ text: String) -> [String] {
        lines(text)
            .filter { !$0.allSatisfy(\.isWhitespace) }
            .map(String.init)
    }

    static func show(logPath: String, includeTests: Bool = false) {
        let formatted: String
        if includeTests {
            let log = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
            let failures = testFailureLines(in: log)
            if failures.isEmpty { return }
            let failuresPath = NSTemporaryDirectory() + "xcb-failures-\(ProcessInfo.processInfo.processIdentifier).log"
            try? (failures.joined(separator: "\n") + "\n").write(toFile: failuresPath, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(atPath: failuresPath) }
            formatted = Shell.capture(["xcbeautify", "--disable-logging"], stdinPath: failuresPath).output
        } else {
            formatted = Shell.capture(["xcbeautify", "--quiet"], stdinPath: logPath).output
        }

        let summary = nonBlankLines(formatted)
        guard !summary.isEmpty else { return }
        echo()
        echo(rule)
        summary.forEach { echo($0) }
        echo(rule)
    }
}
