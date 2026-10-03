import Foundation

/// `test`, `test coverage`, and `purge`.
extension App {
    func test(xcresultPath existingXcresult: String) throws {
        if options.dryRun && reusesResults {
            echo("\(yellow)xcrun xccov view --report --json <most-recent>.xcresult\(reset)")
            return
        }

        let coverage = options.action == .coverage
        echo("🔨 Building and testing scheme: \(options.scheme)")
        echo("   Workspace: \(options.workspace)")
        showDestination()
        echo("   Action: \(options.action.rawValue)")
        if !options.onlyTest.isEmpty {
            echo("   Only: \(options.onlyTest)")
        }

        let onlyTesting = options.onlyTest.isEmpty ? [] : ["-only-testing:\(options.onlyTest)"]

        if options.dryRun {
            var preview = options.quiet ? ["-quiet"] : []
            preview += targetArguments
            if coverage {
                preview += [
                    "-enableCodeCoverage YES",
                    "-resultBundlePath \"/tmp/\(options.scheme)-Coverage-<timestamp>.xcresult\"",
                ]
            }
            preview += onlyTesting
            preview.append("2>&1 | xcbeautify")
            showCommand("xcodebuild test", preview)
            return
        }

        if !reusesResults {
            try requireXcbeautify()
        }

        guard coverage else {
            let logPath = buildLogPath()
            echo()
            let status = try runBeautified(xcodebuild("test", quiet: options.quiet, onlyTesting), logPath: logPath)
            reportTestStatus(status, logPath: logPath)
            playSound(status)
            if status != 0 { throw ExitCode(status) }
            return
        }

        var xcresultPath = existingXcresult
        var status: Int32 = 0
        if !reusesResults {
            // Write the result bundle to /tmp — DerivedData eventually cleans its own copies,
            // and /tmp avoids cluttering the project directory
            let stamp = timestamp()
            xcresultPath = "/tmp/\(options.scheme)-Coverage-\(stamp).xcresult"
            let logPath = buildLogPath(stamp)
            echo("   xcresult: \(xcresultPath)")
            echo()

            let args = xcodebuild("test", quiet: options.quiet, ["-enableCodeCoverage", "YES", "-resultBundlePath", xcresultPath] + onlyTesting)
            status = try runBeautified(args, logPath: logPath)
            reportTestStatus(status, logPath: logPath)
        }

        // Extract and display coverage report
        echo()
        if let report = loadCoverage(xcresultPath) {
            let filter = options.filterScheme ? options.scheme : options.filter
            CoverageFormatter.summary(report, xcresultPath: xcresultPath, modified: modificationDate(xcresultPath), filter: filter)
                .forEach { echo($0) }
            if options.detailed {
                CoverageFormatter.detailed(report, filter: filter).forEach { echo($0) }
            }
        } else {
            echo("\(yellow)⚠ No coverage data found in .xcresult\(reset)")
            echo("\(yellow)Make sure tests were run with code coverage enabled.\(reset)")
            if reusesResults { throw ExitCode(1) }
        }

        echo()
        echo("\(cyan)📁 Full results:\(reset) \(xcresultPath)")
        echo("\(cyan)   View in Xcode:\(reset) open \(xcresultPath)")
        if reusesResults { return }

        playSound(status)
        if status != 0 { throw ExitCode(status) }
    }

    /// xcodebuild exits 65 when tests fail; anything else non-zero is a build failure.
    private func reportTestStatus(_ status: Int32, logPath: String) {
        ErrorSummary.show(logPath: logPath, includeTests: status == 65)
        try? FileManager.default.removeItem(atPath: logPath)
        switch status {
        case 0:
            if options.quiet {
                echo("\(green)Tests passed\(reset)")
            }
        case 65:
            echo()
            echo("\(red)❌ Tests failed\(reset)")
        default:
            echo()
            echo("\(red)❌ Build failed (exit code: \(status))\(reset)")
        }
    }

    private func loadCoverage(_ xcresultPath: String) -> CoverageReport? {
        guard Shell.capture(["xcrun", "--find", "xccov"]).status == 0 else {
            echoError("\(red)✗ xccov command not found\(reset)")
            echoError("\(yellow)Make sure Xcode is installed (xccov requires full Xcode, not just Command Line Tools).\(reset)")
            return nil
        }
        let json = Shell.capture(["xcrun", "xccov", "view", "--report", "--json", xcresultPath]).output
        return try? JSONDecoder().decode(CoverageReport.self, from: Data(json.utf8))
    }

    /// Most recent .xcresult in /tmp, the current directory, or (as a fallback) DerivedData,
    /// optionally limited to bundles whose name contains `name`.
    func findMostRecentXcresult(matching name: String) -> String? {
        var best: (path: String, date: Date)?
        func consider(_ path: String) {
            if !name.isEmpty && !basename(path).contains(name) { return }
            let date = modificationDate(path) ?? .distantPast
            if best == nil || date > best!.date {
                best = (path, date)
            }
        }

        // /tmp first (where test coverage writes results), then the current directory
        xcresults(in: "/tmp").forEach(consider)
        xcresults(in: ".").forEach(consider)

        let derivedData = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        if best == nil, let enumerator = FileManager.default.enumerator(atPath: derivedData) {
            var checked = 0
            while checked < 50, let relative = enumerator.nextObject() as? String {
                guard relative.hasSuffix(".xcresult") else { continue }
                let path = "\(derivedData)/\(relative)"
                guard isDirectory(path) else { continue }
                enumerator.skipDescendants()
                consider(path)
                checked += 1
            }
        }
        return best?.path
    }

    /// .xcresult bundles directly inside `directory`, sorted by path.
    private func xcresults(in directory: String) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        return entries
            .filter { $0.hasSuffix(".xcresult") }
            .map { "\(directory)/\($0)" }
            .filter(isDirectory)
            .sorted()
    }

    func purge() throws {
        let results = xcresults(in: "/tmp")

        if results.isEmpty {
            echo("\(green)✓ No .xcresult bundles found in /tmp\(reset)")
            return
        }

        echo(rule)
        echo("\(bold)🗑  PURGE .xcresult bundles from /tmp\(reset)")
        echo(rule)
        echo()

        for result in results {
            let size = Shell.capture(["du", "-sh", result]).output.split(whereSeparator: \.isWhitespace).first ?? "?"
            echo("  \(yellow)→\(reset) \(basename(result))  \(cyan)(\(size))\(reset)")
        }

        echo()
        echo("  Found \(bold)\(results.count)\(reset) bundle(s)")
        echo()

        if !options.force {
            echo("\(yellow)Remove all of the above? [y/N]\(reset) ", terminator: "")
            let confirm = readChoice()
            if confirm != "y" && confirm != "Y" {
                echo("\(yellow)Cancelled.\(reset)")
                return
            }
        }

        var removed = 0
        for result in results {
            do {
                try FileManager.default.removeItem(atPath: result)
                removed += 1
            } catch {
                echo("\(red)✗ Failed to remove: \(result)\(reset)")
            }
        }

        echo("\(green)✅ Removed \(removed) bundle(s) from /tmp\(reset)")
        echo(rule)
    }
}
