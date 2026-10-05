import Foundation
import Testing
@testable import XCBCore

@Suite struct ConfigFileTests {
    let directory: String
    let config: ConfigFile

    init() throws {
        directory = NSTemporaryDirectory() + "xcb-config-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        config = ConfigFile(path: directory + "/.xcbrc")
    }

    func contents() throws -> String {
        try String(contentsOfFile: config.path, encoding: .utf8)
    }

    func write(_ text: String) throws {
        try text.write(toFile: config.path, atomically: true, encoding: .utf8)
    }

    // MARK: set

    @Test func createsNewKeyInNewFile() throws {
        try config.set("SCHEME", "MyApp")
        #expect(try contents() == "SCHEME=\"MyApp\"\n")
    }

    @Test func createsNewKeyInExistingFile() throws {
        try write("WORKSPACE=\"Test.xcworkspace\"\n")
        try config.set("SCHEME", "MyApp")
        #expect(try contents() == "WORKSPACE=\"Test.xcworkspace\"\nSCHEME=\"MyApp\"\n")
    }

    @Test func updatesExistingKey() throws {
        try write("SCHEME=\"OldScheme\"\n")
        try config.set("SCHEME", "NewScheme")
        #expect(try contents() == "SCHEME=\"NewScheme\"\n")
    }

    @Test func removesKeyWhenValueIsEmpty() throws {
        try write("SCHEME=\"MyApp\"\n")
        try config.set("SCHEME", "")
        #expect(try !contents().contains("SCHEME"))
    }

    @Test func removeIsNoOpWhenKeyMissing() throws {
        try write("WORKSPACE=\"Test.xcworkspace\"\n")
        try config.set("SCHEME", "")
        #expect(try contents() == "WORKSPACE=\"Test.xcworkspace\"\n")
    }

    @Test func removeIsNoOpWhenFileMissing() throws {
        try config.set("SCHEME", "")
        #expect(!FileManager.default.fileExists(atPath: config.path))
    }

    @Test func updateLeavesOtherKeys() throws {
        try write("WORKSPACE=\"Test.xcworkspace\"\nSCHEME=\"OldScheme\"\nSIMULATOR_ID=\"some-uuid\"\n")
        try config.set("SCHEME", "NewScheme")
        let values = config.load()
        #expect(values == ["WORKSPACE": "Test.xcworkspace", "SCHEME": "NewScheme", "SIMULATOR_ID": "some-uuid"])
    }

    @Test(arguments: ["path/to/My.xcworkspace", "Tom & Jerry", #"a/b&c\d"#, "Ben's iPhone"])
    func storesSpecialCharactersVerbatim(value: String) throws {
        try write("DEVICE_NAME=\"old\"\n")
        try config.set("DEVICE_NAME", value)
        #expect(try contents() == "DEVICE_NAME=\"\(value)\"\n")
        #expect(config.load()["DEVICE_NAME"] == value)
    }

    // MARK: parse

    @Test func parsesQuotedUnquotedAndExportedValues() {
        let values = ConfigFile.parse("""
            # comment
            SCHEME="MyApp"
            WORKSPACE=App.xcworkspace

            export DEVICE_NAME='Ben iPhone'
            EMPTY=""
            not a setting
            """)
        #expect(values == [
            "SCHEME": "MyApp",
            "WORKSPACE": "App.xcworkspace",
            "DEVICE_NAME": "Ben iPhone",
            "EMPTY": "",
        ])
    }
}
