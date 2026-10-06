import Foundation

public enum XCB {
    /// Runs xcb with the full argv (including the executable name) and returns the exit status.
    public static func main(_ argv: [String]) -> Int32 {
        do {
            try run(Array(argv.dropFirst()))
            return 0
        } catch let exit as ExitCode {
            return exit.code
        } catch {
            echoError("\(red)Error: \(error)\(reset)")
            return 1
        }
    }

    static func run(_ args: [String]) throws {
        switch args.first {
        case "--parse-build-settings":
            // Hidden subcommand for tests: read showBuildSettings output on stdin,
            // print the parsed app name + path (tab-delimited). Not documented in usage.
            let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
            if let app = Parsers.appProduct(inBuildSettings: input) {
                echo("\(app.name)\t\(app.directory)")
            }
            return
        case "--version", "-v":
            echo("xcb \(xcbVersion)")
            return
        case "--update":
            try Updater.run(dryRun: args.dropFirst().first == "--dry-run")
            return
        default:
            break
        }

        let config = ConfigFile()
        var options = Options()
        options.apply(config: config.load())
        do {
            try options.parse(args)
        } catch let error as UsageError {
            if let message = error.message {
                echo(message)
            }
            echo(options.usage())
            throw ExitCode(1)
        }

        try App(options: options, config: config).execute()
    }
}

/// Executes a parsed command. Split across extensions by action.
final class App {
    var options: Options
    let config: ConfigFile

    /// `-destination` value for xcodebuild, set by `validateDestination()`.
    var destination = ""

    init(options: Options, config: ConfigFile) {
        self.options = options
        self.config = config
    }

    /// `test coverage --skip-build` reports on an existing .xcresult instead of building.
    var reusesResults: Bool {
        options.action == .coverage && options.skipBuild
    }

    func execute() throws {
        switch options.action {
        case .select:
            try select(options.selectTarget!)
            return
        case .setup:
            try selectWorkspace()
            try selectScheme()
            try selectDestination()
            return
        case .purge:
            try purge()
            return
        case .log:
            try log()
            return
        default:
            break
        }

        // Warn if --only is used with non-test actions
        if !options.onlyTest.isEmpty && (![.test, .coverage].contains(options.action) || reusesResults) {
            echo("\(yellow)⚠ --only is ignored in \(options.action.rawValue) action\(reset)")
            options.onlyTest = ""
        }

        var xcresultPath = ""
        if reusesResults {
            if !options.dryRun {
                echo("\(blue)🔍 Searching for most recent .xcresult...\(reset)")
                guard let found = findMostRecentXcresult(matching: options.scheme) else {
                    echo("\(red)Error: No .xcresult found in current directory or DerivedData\(reset)")
                    echo("\(yellow)Tip: Run tests with coverage first\(reset)")
                    throw ExitCode(1)
                }
                xcresultPath = found
                echo("\(green)✓ Found: \(basename(found))\(reset)")
            }
        } else {
            if options.scheme.isEmpty {
                echo("\(red)Error: Scheme is required\(reset)")
                echo("\(yellow)Tip: Run 'xcb select scheme' or pass -s <scheme>\(reset)")
                throw ExitCode(1)
            }
            try validateDestination()
        }

        switch options.action {
        case .clean: try clean()
        case .build: try build(andRun: false)
        case .buildRun: try build(andRun: true)
        case .run: try runLastBuild()
        case .test, .coverage: try test(xcresultPath: xcresultPath)
        case .select, .setup, .purge, .log: break
        }
    }

    func validateDestination() throws {
        if options.workspace.isEmpty {
            echo("\(red)Error: Workspace is not set\(reset)")
            echo("\(yellow)Tip: Run 'xcb select workspace' or pass -w <workspace>\(reset)")
            throw ExitCode(1)
        }

        // Default to simulator for backward compatibility
        if options.destinationType.isEmpty {
            options.destinationType = "simulator"
        }

        switch options.destinationType {
        case "simulator":
            if options.simulatorID.isEmpty {
                echo("\(red)Error: Simulator is not set\(reset)")
                echo("\(yellow)Tip: Run 'xcb select simulator' or pass --simulator-id <uuid>\(reset)")
                throw ExitCode(1)
            }
            destination = "platform=iOS Simulator,id=\(options.simulatorID)"
        case "device":
            if options.deviceID.isEmpty {
                echo("\(red)Error: Device identifier is not set\(reset)")
                echo("\(yellow)Tip: Run 'xcb select device' or pass --device-id <uuid>\(reset)")
                throw ExitCode(1)
            }
            destination = "platform=iOS,id=\(options.deviceID)"
        default:
            echo("\(red)Error: Unknown destination type '\(options.destinationType)'\(reset)")
            echo("\(yellow)Tip: Use 'simulator' or 'device'\(reset)")
            throw ExitCode(1)
        }
    }

    // MARK: - Shared helpers

    func requireXcbeautify() throws {
        if Shell.which("xcbeautify") == nil {
            echo("\(red)Error: xcbeautify is not installed\(reset)")
            echo("\(yellow)Install with: brew install xcbeautify\(reset)")
            throw ExitCode(1)
        }
    }

    func playSound(_ status: Int32) {
        guard options.audible, Shell.which("afplay") != nil else { return }
        let sound = status == 0 ? "/System/Library/Sounds/Glass.aiff" : "/System/Library/Sounds/Basso.aiff"
        Shell.spawnDetached(["afplay", sound])
    }

    /// Print the destination line for status output
    func showDestination() {
        if options.destinationType == "device" {
            echo("   Destination: \(options.deviceName.or(options.deviceID)) device")
        } else {
            var label = options.simulatorName.or(options.simulatorID)
            if !options.simulatorOS.isEmpty {
                label += " (iOS \(options.simulatorOS))"
            }
            echo("   Destination: \(label) simulator")
        }
    }

    /// Print a dry-run command in yellow, one argument per line with `\` continuations.
    func showCommand(_ command: String, _ arguments: [String]) {
        let all = [command] + arguments.map { "    \($0)" }
        for (index, line) in all.enumerated() {
            let continuation = index < all.count - 1 ? " \\" : ""
            echo("\(yellow)\(line)\(continuation)\(reset)")
        }
    }

    func xcodebuild(_ verb: String, quiet: Bool = false, _ extra: [String] = []) -> [String] {
        var args = ["xcodebuild", verb]
        if quiet {
            args.append("-quiet")
        }
        args += ["-workspace", options.workspace, "-scheme", options.scheme, "-destination", destination]
        return args + extra
    }

    /// Dry-run lines for the standard -workspace/-scheme/-destination arguments.
    var targetArguments: [String] {
        [
            "-workspace \"\(options.workspace)\"",
            "-scheme \"\(options.scheme)\"",
            "-destination \"\(destination)\"",
        ]
    }

    func buildLogPath(_ timestamp: String = timestamp()) -> String {
        "/tmp/xcodebuild-\(options.scheme)-\(timestamp).log"
    }

    /// Run xcodebuild through xcbeautify, keeping the raw log for the error summary.
    func runBeautified(_ args: [String], logPath: String) throws -> Int32 {
        try Shell.runTee(args, logPath: logPath, filter: ["xcbeautify"])
    }

    /// Runs `xcodebuild clean`, printing only its last line of output.
    func runClean() -> Int32 {
        let (status, output) = Shell.capture(xcodebuild("clean"), mergeStderr: true)
        if let last = output.split(separator: "\n").last {
            echo(String(last))
        }
        return status
    }
}
