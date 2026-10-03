import Foundation
import Testing
@testable import XCBCore

@Suite struct SimctlParsingTests {
    typealias Simulator = Parsers.Simulator

    @Test func parsesStandardDeviceLine() {
        let result = Parsers.simulators(inSimctl: """
            -- iOS 18.0 --
                iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
            """)
        #expect(result == [Simulator(name: "iPhone 16", id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", os: "18.0")])
    }

    @Test func parsesBootedSimulator() {
        let result = Parsers.simulators(inSimctl: """
            -- iOS 18.0 --
                iPhone 16 Pro Max (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Booted)
            """)
        #expect(result == [Simulator(name: "iPhone 16 Pro Max", id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", os: "18.0")])
    }

    @Test func parsesMultipleDevicesAcrossOSVersions() {
        let result = Parsers.simulators(inSimctl: """
            -- iOS 17.5 --
                iPhone 15 (11111111-2222-3333-4444-555555555555) (Shutdown)
            -- iOS 18.0 --
                iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
                iPhone 16 Pro (FFFFFFFF-1111-2222-3333-444444444444) (Booted)
            """)
        #expect(result == [
            Simulator(name: "iPhone 15", id: "11111111-2222-3333-4444-555555555555", os: "17.5"),
            Simulator(name: "iPhone 16", id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", os: "18.0"),
            Simulator(name: "iPhone 16 Pro", id: "FFFFFFFF-1111-2222-3333-444444444444", os: "18.0"),
        ])
    }

    @Test func parsesParenthesesInName() {
        let result = Parsers.simulators(inSimctl: """
            -- iOS 18.0 --
                iPad Pro (13-inch) (M4) (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
            """)
        #expect(result == [Simulator(name: "iPad Pro (13-inch) (M4)", id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", os: "18.0")])
    }

    @Test func skipsNonIOSSections() {
        let result = Parsers.simulators(inSimctl: """
            == Devices ==
            -- iOS 18.0 --
                iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
            -- tvOS 18.0 --
                Apple TV (FFFFFFFF-1111-2222-3333-444444444444) (Shutdown)
            """)
        #expect(result.map(\.name) == ["iPhone 16"])
    }

    @Test func handlesNoDevices() {
        #expect(Parsers.simulators(inSimctl: "== Devices ==\n").isEmpty)
    }
}

@Suite struct BuildSettingsParsingTests {
    @Test func picksAppWhenFrameworkTargetAppearsFirst() throws {
        let app = try #require(Parsers.appProduct(inBuildSettings: """
            Build settings for action build and target "MyKit":
                BUILT_PRODUCTS_DIR = /WRONG/framework/dir
                FULL_PRODUCT_NAME = MyKit.framework

            Build settings for action build and target "MyApp":
                BUILT_PRODUCTS_DIR = /Users/me/Build Products/Debug-iphonesimulator
                FULL_PRODUCT_NAME = MyApp.app
                PRODUCT_BUNDLE_IDENTIFIER = com.example.MyApp
            """))
        #expect(app.name == "MyApp.app")
        #expect(app.directory == "/Users/me/Build Products/Debug-iphonesimulator")
    }

    @Test func ignoresSimilarlyNamedSettings() throws {
        let app = try #require(Parsers.appProduct(inBuildSettings: """
                BUILT_PRODUCTS_DIR = /right
                BUILT_PRODUCTS_DIR_SUFFIX = /wrong
                FULL_PRODUCT_NAME = MyApp.app
            """))
        #expect(app.directory == "/right")
    }

    @Test func returnsNilWithoutAppTarget() {
        #expect(Parsers.appProduct(inBuildSettings: """
                BUILT_PRODUCTS_DIR = /tmp/Build
                FULL_PRODUCT_NAME = MyKitTests.xctest
            """) == nil)
    }
}

@Suite struct SchemeListParsingTests {
    @Test func parsesSchemesSection() {
        let output = """
            Information about workspace "MyApp":
                Schemes:
                    MyApp
                    MyKit
                    My App Tests

            Some other section:
                Unrelated
            """
        #expect(Parsers.schemes(inList: output) == ["MyApp", "MyKit", "My App Tests"])
    }

    @Test func returnsEmptyWithoutSchemes() {
        #expect(Parsers.schemes(inList: "xcodebuild: error: no workspace\n").isEmpty)
    }
}

@Suite struct DevicectlParsingTests {
    @Test func returnsOnlyConnectedIOSDevices() throws {
        let json = """
            {"result": {"devices": [
              {"hardwareProperties": {"platform": "iOS", "udid": "UDID-1", "marketingName": "iPhone 16 Pro", "productType": "iPhone17,1"},
               "deviceProperties": {"name": "Ben's iPhone", "osVersionNumber": "26.0"},
               "connectionProperties": {"transportType": "wired"}},
              {"hardwareProperties": {"platform": "iOS", "udid": "UDID-2", "productType": "iPad16,3"},
               "deviceProperties": {"name": "Old iPad", "osVersionNumber": "18.1"},
               "connectionProperties": {"transportType": "localNetwork"}},
              {"hardwareProperties": {"platform": "iOS", "udid": "UDID-3"},
               "deviceProperties": {"name": "Disconnected"},
               "connectionProperties": {}},
              {"hardwareProperties": {"platform": "watchOS", "udid": "UDID-4"},
               "deviceProperties": {"name": "Watch"},
               "connectionProperties": {"transportType": "wired"}}
            ]}}
            """
        let devices = try Parsers.devices(inDevicectlJSON: Data(json.utf8))
        #expect(devices == [
            Parsers.Device(name: "Ben's iPhone", id: "UDID-1", model: "iPhone 16 Pro", os: "26.0"),
            Parsers.Device(name: "Old iPad", id: "UDID-2", model: "iPad16,3", os: "18.1"),
        ])
    }
}
