import Testing
@testable import XCBCore

@Suite struct OptionsTests {
    func parse(_ args: String) throws -> Options {
        var options = Options()
        try options.parse(args.split(separator: " ").map(String.init))
        return options
    }

    @Test(arguments: [
        ("build", Action.build),
        ("build run", .buildRun),
        ("test", .test),
        ("test coverage", .coverage),
        ("run", .run),
        ("clean", .clean),
        ("purge", .purge),
        ("setup", .setup),
        ("log", .log),
    ])
    func mapsActionsAndSubActions(args: String, expected: Action) throws {
        #expect(try parse(args).action == expected)
    }

    @Test func mapsLegacySelectIphoneToSimulator() throws {
        #expect(try parse("select iphone").selectTarget == .simulator)
    }

    @Test func parsesFlags() throws {
        let options = try parse("test coverage -s App -w App.xcworkspace -d device --device-id D --only T/C --filter Kit --detailed -q -a")
        #expect(options.scheme == "App")
        #expect(options.workspace == "App.xcworkspace")
        #expect(options.destinationType == "device")
        #expect(options.deviceID == "D")
        #expect(options.onlyTest == "T/C")
        #expect(options.filter == "Kit")
        #expect(options.detailed && options.quiet && options.audible)
    }

    @Test func parsesLogFlags() throws {
        let options = try parse("log --subsystem com.example.app -c Networking --category Auth*")
        #expect(options.subsystem == "com.example.app")
        #expect(options.categories == ["Networking", "Auth*"])
        #expect(options.logLevel == "debug")
    }

    @Test(arguments: ["default", "info", "debug"])
    func parsesLogLevel(level: String) throws {
        #expect(try parse("log --level \(level)").logLevel == level)
    }

    @Test func mapsSelectSubsystem() throws {
        #expect(try parse("select subsystem").selectTarget == .subsystem)
    }

    @Test func loadsSubsystemFromConfig() throws {
        var options = Options()
        options.apply(config: ["LOG_SUBSYSTEM": "com.example.app"])
        try options.parse(["log"])
        #expect(options.subsystem == "com.example.app")
    }

    @Test func flagsOverrideConfig() throws {
        var options = Options()
        options.apply(config: ["SCHEME": "Saved", "WORKSPACE": "Saved.xcworkspace"])
        try options.parse(["build", "-s", "Override"])
        #expect(options.scheme == "Override")
        #expect(options.workspace == "Saved.xcworkspace")
    }

    @Test(arguments: ["", "foobar", "build nope", "test nope", "select", "select nope", "run extra", "log extra", "log -c", "log --level", "log --level error", "build --bogus", "build -s", "build --help"])
    func rejectsInvalidCommandLines(args: String) {
        #expect(throws: UsageError.self) { try parse(args) }
    }
}
