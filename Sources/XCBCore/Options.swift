import Foundation

enum Action: String {
    case select, setup, purge, clean, build
    case buildRun = "build-run"
    case run, test, coverage
}

enum SelectTarget: String {
    case workspace, scheme, destination, simulator, device
}

/// Settings from `.xcbrc` (saved via `select` commands) overridden by CLI flags.
struct Options {
    var workspace = ""
    var simulatorName = ""    // Human-readable simulator name (for display only)
    var simulatorID = ""      // simctl UUID for simulator
    var simulatorOS = ""      // iOS version for simulator (for display only)
    var scheme = ""
    var destinationType = ""  // "simulator" or "device"
    var deviceID = ""         // CoreDevice identifier (UUID) for physical devices
    var deviceName = ""       // Human-readable device name (for display only)

    var action: Action = .build
    var selectTarget: SelectTarget?
    var skipBuild = false
    var detailed = false
    var onlyTest = ""
    var force = false
    var filter = ""
    var filterScheme = false
    var dryRun = false
    var clean = false
    var audible = false
    var quiet = false

    /// Apply saved defaults from `.xcbrc`.
    mutating func apply(config: [String: String]) {
        workspace = config["WORKSPACE"] ?? workspace
        simulatorName = config["SIMULATOR_NAME"] ?? simulatorName
        simulatorID = config["SIMULATOR_ID"] ?? simulatorID
        simulatorOS = config["SIMULATOR_OS"] ?? simulatorOS
        scheme = config["SCHEME"] ?? scheme
        destinationType = config["DESTINATION_TYPE"] ?? destinationType
        deviceID = config["DEVICE_ID"] ?? deviceID
        deviceName = config["DEVICE_NAME"] ?? deviceName

        // Backward compatibility: migrate IPHONE_NAME from old .xcbrc files
        let legacyName = config["IPHONE_NAME"] ?? ""
        let legacyOS = config["OS_VERSION"] ?? ""
        if !legacyName.isEmpty && simulatorName.isEmpty {
            simulatorName = legacyName
        }
        // Detect old config that can't be auto-migrated (name/version but no UUID)
        if !(legacyName + legacyOS).isEmpty && simulatorID.isEmpty {
            echo("\(yellow)Note: Your .xcbrc uses the old IPHONE_NAME/OS_VERSION format.\(reset)")
            echo("\(yellow)Run 'xcb select simulator' to update your config.\(reset)")
            echo()
        }
    }
}

/// Invalid command line: print the message (if any) followed by usage, then exit 1.
struct UsageError: Error {
    let message: String?
    init(_ message: String? = nil) { self.message = message }
}

extension Options {
    /// Parse `<action> [sub-action] [flags...]` on top of the current values.
    mutating func parse(_ arguments: [String]) throws {
        var args = arguments[...]

        // Positional action and sub-action
        var parsedAction: Action?
        if let first = args.first, !first.hasPrefix("-") {
            switch first {
            case "build", "test", "run", "clean", "purge", "select", "setup":
                args.removeFirst()
                parsedAction = Action(rawValue: first)
                if let sub = args.first, !sub.hasPrefix("-") {
                    args.removeFirst()
                    switch first {
                    case "test":
                        guard sub == "coverage" else { throw UsageError("Error: Unknown test sub-action '\(sub)'") }
                        parsedAction = .coverage
                    case "build":
                        guard sub == "run" else { throw UsageError("Error: Unknown build sub-action '\(sub)'") }
                        parsedAction = .buildRun
                    case "select":
                        if sub == "iphone" {
                            selectTarget = .simulator
                        } else if let target = SelectTarget(rawValue: sub) {
                            selectTarget = target
                        } else {
                            throw UsageError("Error: Unknown select sub-action '\(sub)'")
                        }
                    default:
                        throw UsageError("Error: '\(first)' does not take a sub-action")
                    }
                }
            default:
                break
            }
        }
        guard let parsedAction else { throw UsageError() }
        action = parsedAction

        // Flags
        while let flag = args.popFirst() {
            func value() throws -> String {
                guard let value = args.popFirst() else { throw UsageError("Error: \(flag) requires a value") }
                return value
            }
            switch flag {
            case "-s", "--scheme": scheme = try value()
            case "-w", "--workspace": workspace = try value()
            case "-d", "--destination": destinationType = try value()
            case "--simulator-id": simulatorID = try value()
            case "--device-id": deviceID = try value()
            case "-i", "--iphone":
                echoError("\(yellow)Warning: -i/--iphone is deprecated and was ignored. Use 'xcb select simulator' or --simulator-id instead.\(reset)")
                _ = args.popFirst()
            case "-o", "--os-version":
                echoError("\(yellow)Warning: -o/--os-version is deprecated and was ignored. Use 'xcb select simulator' or --simulator-id instead.\(reset)")
                _ = args.popFirst()
            case "--detailed": detailed = true
            case "--force": force = true
            case "--filter": filter = try value()
            case "--filter-scheme": filterScheme = true
            case "--clean": clean = true
            case "-q", "--quiet": quiet = true
            case "-a", "--audible": audible = true
            case "--dry-run": dryRun = true
            case "--skip-build": skipBuild = true
            case "--only": onlyTest = try value()
            case "-h", "--help": throw UsageError()
            default: throw UsageError("Unknown option: \(flag)")
            }
        }

        if action == .select && selectTarget == nil {
            throw UsageError("Error: 'select' requires a sub-action (scheme or simulator)")
        }
    }

    func usage() -> String {
        """
        Usage: xcb <action> [sub-action] -s <scheme> [options...]

        Actions:
          select workspace       Pick default Xcode workspace
          select scheme          Pick default scheme from workspace
          select destination     Pick default destination (simulator or device)
          select simulator       Pick default simulator
          select device          Pick default physical device (experimental)
          setup                  Select workspace, scheme, and destination

          clean                  Clean derived data for scheme
          build                  Build only
          build run              Build and run app on simulator or device
          run                    Run last built app on simulator or device (no build)

          test                   Build and run tests
          test coverage          Build and run tests with code coverage report

          purge                  Remove coverage files from /tmp

        Options:
          -s, --scheme <name>    Xcode scheme (\(scheme.or("not set, use 'select scheme'")))
          -w, --workspace <path> Xcode workspace (\(workspace.or("not set, use 'select workspace'")))
          -d, --destination <type> simulator or device [device is experimental] (\(destinationType.or("not set, use 'select destination'")))
          --simulator-id <uuid>  Simulator identifier (\(simulatorID.or("not set, use 'select simulator'")))
          --device-id <uuid>     Physical device identifier (experimental) (\(deviceID.or("not set, use 'select device'")))
          --only <test>          Run specific test(s) (test actions only)
                                 Format: TestTarget/TestClass[/testMethod]
          --skip-build           Skip build, use results from last run (test coverage)
          --detailed             File-level coverage breakdown (test coverage)
          --clean                Clean before building (build actions only)
          --filter <text>        Filter by text (select scheme, test coverage)
          --filter-scheme        Filter coverage targets by scheme name
          --dry-run              Show the command without running it
          -q, --quiet            Reduce output to build info and summary only
          -a, --audible          Play a sound when the command finishes
          --force                Skip confirmation (purge only)
          -v, --version          Print xcb version and exit
          --update               Update xcb to the latest version from GitHub
          -h, --help             Show this help

        Examples:
          xcb select workspace            Pick a default workspace
          xcb select scheme              Pick a default scheme
          xcb select simulator           Pick a default simulator
          xcb test -s MyScheme
          xcb test -s MyScheme --only MyTests/MyTestClass
          xcb test coverage -s MyScheme --detailed
          xcb test coverage --skip-build -s MyScheme
          xcb build -s MyApp
          xcb build run -s MyApp
          xcb run -s MyApp
          xcb setup                       Interactive setup (workspace, scheme, destination)
          xcb purge --force
        """
    }
}

extension String {
    /// This string, or `fallback` if empty (like bash `${VAR:-fallback}`).
    func or(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
