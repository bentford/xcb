import Foundation
#if canImport(Glibc)
import Glibc
#endif

/// `xcb --update`: compare against the latest GitHub release and re-run the installer.
enum Updater {
    static let installURL = "https://raw.githubusercontent.com/bentford/xcb/main/install.sh"
    static let latestReleaseURL = "https://github.com/bentford/xcb/releases/latest"
    static let changelogURL = "https://github.com/bentford/xcb/blob/main/CHANGELOG.md"

    static func run(dryRun: Bool) throws {
        guard Shell.which("curl") != nil else {
            echoError("Error: curl is required to update xcb")
            throw ExitCode(1)
        }

        // install.sh writes to $HOME/bin/xcb. If the running xcb lives elsewhere
        // (Homebrew, /usr/local/bin, custom path), the install would create a second
        // copy rather than upgrade the one in use.
        let runningPath = runningExecutablePath()
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let expectedPath = resolvingDirectory("\(home)/bin") + "/xcb"

        echo("Checking for updates...")
        // /releases/latest redirects to /releases/tag/vX.Y.Z; follow it and read the tag
        let finalURL = Shell.capture(["curl", "-fsSLI", "-o", "/dev/null", "-w", "%{url_effective}", latestReleaseURL]).output
        guard let remoteVersion = releaseVersion(fromTagURL: finalURL) else {
            echoError("Error: could not fetch remote version from \(latestReleaseURL)")
            throw ExitCode(1)
        }
        if remoteVersion == xcbVersion {
            echo("xcb is up to date (v\(xcbVersion))")
            return
        }
        if runningPath != expectedPath {
            echo()
            echo("Warning: running xcb is at \(runningPath)")
            echo("         but the installer writes to \(expectedPath)")
            echo("         Updating will create a second copy at \(expectedPath)")
            echo("         instead of upgrading the one currently on your PATH.")
            echo()
        }
        if dryRun {
            echo("Would update xcb \(xcbVersion) -> \(remoteVersion)")
            echo("Would run: curl -fsSL \(installURL) | bash")
            echo("Changelog: \(changelogURL)")
            return
        }
        echo("Updating xcb \(xcbVersion) -> \(remoteVersion)...")
        guard Shell.run(["bash", "-c", "set -o pipefail; curl -fsSL '\(installURL)' | bash"]) == 0 else {
            echoError("Error: update failed")
            throw ExitCode(1)
        }
        echo("xcb updated to v\(remoteVersion)")
        echo("Changelog: \(changelogURL)")
    }

    /// "0.2.0" from ".../releases/tag/v0.2.0". Nil if the URL isn't a release tag.
    static func releaseVersion(fromTagURL url: String) -> String? {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = url.range(of: "/releases/tag/") else { return nil }
        var tag = url[range.upperBound...]
        if tag.hasPrefix("v") {
            tag = tag.dropFirst()
        }
        guard let version = tag.removingPercentEncoding, !version.isEmpty, !version.contains("/") else { return nil }
        return version
    }

    /// Path of the running executable with its directory's symlinks resolved.
    /// argv[0] is a bare name when xcb was found via PATH, so look it up the same way.
    private static func runningExecutablePath() -> String {
        let argv0 = CommandLine.arguments[0]
        let invoked = argv0.contains("/") ? argv0 : (Shell.which(argv0) ?? argv0)
        let url = URL(fileURLWithPath: invoked)
        return resolvingDirectory(url.deletingLastPathComponent().path) + "/" + url.lastPathComponent
    }

    private static func resolvingDirectory(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
