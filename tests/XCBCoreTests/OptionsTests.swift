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

    @Test(arguments: ["--last-results", "--skip-build"])
    func parsesLastResultsAndItsOldName(flag: String) throws {
        #expect(try parse("test coverage \(flag)").lastResults)
    }

    @Test func skipsPackageUpdatesOnlyWhenAskedTo() throws {
        #expect(try parse("build").skipPackageUpdates == false)
        #expect(try parse("build --skip-package-updates").skipPackageUpdates)
    }

    @Test(arguments: [("1", true), ("true", true), ("YES", true), ("0", false), ("false", false), ("", false)])
    func loadsSkipPackageUpdatesFromConfig(value: String, expected: Bool) {
        var options = Options()
        options.apply(config: ["SKIP_PACKAGE_UPDATES": value])
        #expect(options.skipPackageUpdates == expected)
    }

    @Test func flagOverridesSavedSkipPackageUpdates() throws {
        var options = Options()
        options.apply(config: ["SKIP_PACKAGE_UPDATES": "1"])
        try options.parse(["build", "--no-skip-package-updates"])
        #expect(options.skipPackageUpdates == false)
    }

    @Test(arguments: [("0", false), ("false", false), ("NO", false), ("off", false), ("1", true), ("", true), ("nope", true)])
    func loadsFastAppLookupFromConfig(value: String, expected: Bool) {
        var options = Options()
        options.apply(config: ["FAST_APP_LOOKUP": value])
        #expect(options.fastAppLookup == expected)
    }

    @Test func fastAppLookupFlagsOverrideConfig() throws {
        var off = Options()
        off.apply(config: ["FAST_APP_LOOKUP": "0"])
        try off.parse(["run", "--fast-app-lookup"])
        #expect(off.fastAppLookup)

        var on = Options()
        try on.parse(["run", "--no-fast-app-lookup"])
        #expect(on.fastAppLookup == false)
    }

    @Test(arguments: ["", "foobar", "build nope", "test nope", "select", "select nope", "run extra", "log extra", "log -c", "log --level", "log --level error", "build --bogus", "build -s", "build --help"])
    func rejectsInvalidCommandLines(args: String) {
        #expect(throws: UsageError.self) { try parse(args) }
    }
}
