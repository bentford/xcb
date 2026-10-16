import Foundation

/// Locates the simulator UI app that ships with the active Xcode.
///
/// `open -a Simulator` asks LaunchServices for *any* app named Simulator. Xcode 27
/// replaced Simulator.app with DeviceHub.app, so that lookup lands on an older
/// Xcode's Simulator.app, which then fights DeviceHub and can shut devices down.
enum SimulatorApp {
    /// Candidate bundles relative to the developer dir (`xcode-select -p`),
    /// newest layout first.
    static let candidates = [
        "../Applications/DeviceHub.app", // Xcode 27+
        "Applications/Simulator.app", // Xcode 26 and earlier
    ]

    /// Path of the first candidate that exists under `developerDir`, or nil.
    static func path(developerDir: String, exists: (String) -> Bool = FileManager.default.fileExists(atPath:)) -> String? {
        let base = URL(fileURLWithPath: developerDir)
        return candidates
            .map { base.appendingPathComponent($0).standardizedFileURL.path }
            .first(where: exists)
    }

    /// The `open` arguments for the active Xcode's simulator UI, falling back
    /// to a name lookup when the developer dir can't be resolved.
    static func openArguments() -> [String] {
        let developerDir = Shell.capture(["xcode-select", "-p"]).output
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !developerDir.isEmpty, let app = path(developerDir: developerDir) else {
            return ["open", "-a", "Simulator"]
        }
        return ["open", app]
    }
}
