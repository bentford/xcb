import Testing
@testable import XCBCore

@Suite struct SimulatorAppTests {
    private static let xcode27 = "/Applications/Xcode-27.0.0.app/Contents/Developer"
    private static let xcode26 = "/Applications/Xcode-26.3.0.app/Contents/Developer"
    private static let deviceHub27 = "/Applications/Xcode-27.0.0.app/Contents/Applications/DeviceHub.app"
    private static let simulator26 = "/Applications/Xcode-26.3.0.app/Contents/Developer/Applications/Simulator.app"

    @Test(arguments: [
        // Active Xcode 27 picks its own DeviceHub, never another Xcode's Simulator.app
        (xcode27, [deviceHub27, simulator26], deviceHub27),
        // Active Xcode 26 still gets its Simulator.app
        (xcode26, [deviceHub27, simulator26], simulator26),
        // Trailing slash from xcode-select is tolerated
        (xcode27 + "/", [deviceHub27], deviceHub27),
        // Nothing installed under the active Xcode
        (xcode27, [simulator26], nil),
    ] as [(String, [String], String?)])
    func resolvesAppForActiveXcode(developerDir: String, installed: [String], expected: String?) {
        let result = SimulatorApp.path(developerDir: developerDir, exists: installed.contains)
        #expect(result == expected, "developerDir=\(developerDir) installed=\(installed)")
    }
}
