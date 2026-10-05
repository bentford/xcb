import Foundation

/// The `.xcbrc` file: shell-style KEY="VALUE" lines in the working directory.
struct ConfigFile {
    let path: String

    init(path: String = ".xcbrc") {
        self.path = path
    }

    func load() -> [String: String] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
        return Self.parse(text)
    }

    /// Parses KEY=VALUE lines, stripping one layer of surrounding quotes.
    /// Blank lines, comments, and lines without `=` are ignored.
    static func parse(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for raw in lines(text) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count))
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq])
            var value = String(line[line.index(after: eq)...])
            if value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" {
                value = String(value.dropFirst().dropLast())
            }
            values[key] = value
        }
        return values
    }

    /// Write or update KEY="VALUE", or remove the key if value is empty.
    func set(_ key: String, _ value: String) throws {
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        var entries = lines(existing).map(String.init)
        if entries.last == "" { entries.removeLast() }

        let prefix = "\(key)="
        let hadKey = entries.contains { $0.hasPrefix(prefix) }
        if value.isEmpty && !hadKey { return }

        entries.removeAll { $0.hasPrefix(prefix) }
        if !value.isEmpty {
            entries.append("\(key)=\"\(value)\"")
        }
        let text = entries.isEmpty ? "" : entries.joined(separator: "\n") + "\n"
        try text.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
