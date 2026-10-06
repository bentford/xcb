import Foundation

/// `log`: stream the app's os_log output from the simulator.
extension App {
    func log() throws {
        // Default to simulator for backward compatibility
        if options.destinationType.isEmpty {
            options.destinationType = "simulator"
        }
        switch options.destinationType {
        case "simulator":
            break
        case "device":
            echo("\(red)Error: log only supports simulators\(reset)")
            echo("\(yellow)Tip: Run 'xcb select simulator' or pass -d simulator --simulator-id <uuid>\(reset)")
            throw ExitCode(1)
        default:
            echo("\(red)Error: Unknown destination type '\(options.destinationType)'\(reset)")
            echo("\(yellow)Tip: Use 'simulator' or 'device'\(reset)")
            throw ExitCode(1)
        }
        if options.simulatorID.isEmpty {
            echo("\(red)Error: Simulator is not set\(reset)")
            echo("\(yellow)Tip: Run 'xcb select simulator' or pass --simulator-id <uuid>\(reset)")
            throw ExitCode(1)
        }

        var subsystem = options.subsystem
        if subsystem.isEmpty {
            subsystem = options.dryRun ? "<bundle-id>" : try bundleIDForLogging()
        }

        let simulatorID = options.simulatorID
        let predicate = LogPredicate.make(subsystem: subsystem, categories: options.categories)
        let arguments = ["--level=\(options.logLevel)", "--predicate", predicate, "--style", "compact"]

        if options.dryRun {
            showCommand("xcrun simctl spawn \"\(simulatorID)\" log stream", [
                "--level=\(options.logLevel)",
                "--predicate '\(predicate)'",
                "--style compact",
            ])
            return
        }

        let simctlOutput = Shell.capture(["xcrun", "simctl", "list", "devices"]).output
        guard Parsers.simulatorIsBooted(simulatorID, inSimctl: simctlOutput) else {
            echo("\(red)Error: Simulator is not booted\(reset)")
            echo("\(yellow)Tip: Run 'xcb run' to boot it and launch the app, or 'xcrun simctl boot \(simulatorID)'\(reset)")
            throw ExitCode(1)
        }

        echo("\(bold)Streaming logs...\(reset)")
        showDestination()
        echo("   Subsystem: \(subsystem)")
        if !options.categories.isEmpty {
            echo("   Categories: \(options.categories.joined(separator: " "))")
        }
        echo("   Level: \(options.logLevel)")
        echo()
        echo("\(yellow)Press Ctrl+C to stop\(reset)")
        echo()

        try Shell.exec(["xcrun", "simctl", "spawn", simulatorID, "log", "stream"] + arguments)
    }

    /// The scheme's built app's bundle ID, which apps conventionally use as their subsystem.
    private func bundleIDForLogging() throws -> String {
        if options.scheme.isEmpty {
            echo("\(red)Error: Subsystem is not set\(reset)")
            echo("\(yellow)Tip: Pass --subsystem <name>, run 'xcb select subsystem', or set a scheme to use its bundle ID\(reset)")
            throw ExitCode(1)
        }
        try validateDestination()

        echo("\(blue)🔍 Reading bundle ID from build settings...\(reset)")
        guard let bundleID = resolveBuiltApp()?.bundleID else {
            echo("\(red)Error: Could not determine the app's bundle ID. Have you built the app yet?\(reset)")
            echo("\(yellow)Tip: Run 'xcb build run' first, or pass --subsystem <name>\(reset)")
            throw ExitCode(1)
        }
        return bundleID
    }
}

/// Builds the `log stream --predicate` filter.
enum LogPredicate {
    /// `subsystem == "x"`, plus `AND (category == "a" OR category LIKE "b*")` when
    /// categories are given. Categories containing `*` match as wildcards.
    static func make(subsystem: String, categories: [String]) -> String {
        var predicate = "subsystem == \(quoted(subsystem))"
        if !categories.isEmpty {
            let terms = categories.map { category in
                category.contains("*") ? "category LIKE \(quoted(category))" : "category == \(quoted(category))"
            }
            predicate += " AND (\(terms.joined(separator: " OR ")))"
        }
        return predicate
    }

    /// An NSPredicate string literal, with backslashes and double quotes escaped.
    private static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
