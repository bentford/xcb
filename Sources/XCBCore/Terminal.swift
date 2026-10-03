import Foundation

// ANSI colors for output
let red = "\u{1B}[0;31m"
let green = "\u{1B}[0;32m"
let yellow = "\u{1B}[1;33m"
let blue = "\u{1B}[0;34m"
let cyan = "\u{1B}[0;36m"
let bold = "\u{1B}[1m"
let reset = "\u{1B}[0m"

/// Bold horizontal rule used to frame reports and summaries.
let rule = "\(bold)\(String(repeating: "━", count: 48))\(reset)"

/// Thrown to stop execution and exit with the given status.
public struct ExitCode: Error {
    public let code: Int32
    public init(_ code: Int32) { self.code = code }
}

/// Writes to stdout unbuffered, so our output stays in order with the output
/// of child processes (xcodebuild, xcbeautify, simctl) that share the terminal.
func echo(_ text: String = "", terminator: String = "\n") {
    FileHandle.standardOutput.write(Data((text + terminator).utf8))
}

func echoError(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}

/// Reads one line from stdin, trimmed like bash `read -r`. Nil on EOF.
func readChoice() -> String? {
    readLine()?.trimmingCharacters(in: .whitespaces)
}

func timestamp() -> String {
    format(Date(), "yyyyMMdd_HHmmss")
}

func format(_ date: Date, _ pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = pattern
    return formatter.string(from: date)
}

/// Modification date of a path, following symlinks.
func modificationDate(_ path: String) -> Date? {
    let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    let attributes = try? FileManager.default.attributesOfItem(atPath: resolved)
    return attributes?[.modificationDate] as? Date
}

func isDirectory(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

func basename(_ path: String) -> String {
    path.split(separator: "/").last.map(String.init) ?? path
}

func lines(_ text: String) -> [Substring] {
    text.split(separator: "\n", omittingEmptySubsequences: false)
}
