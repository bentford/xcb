import Foundation

/// `clean`, `build`, `build run`, and `run`.
extension App {
    func clean() throws {
        echo("Cleaning: \(options.scheme)")
        echo("   Workspace: \(options.workspace)")
        showDestination()
        echo()

        if options.dryRun {
            showCommand("xcodebuild clean", targetArguments)
            return
        }

        let status = runClean()
        if status != 0 {
            echo("\(red)Clean failed (exit code: \(status))\(reset)")
            playSound(status)
            throw ExitCode(status)
        }
        echo("\(green)Clean succeeded\(reset)")
        playSound(0)
    }

    func build(andRun: Bool) throws {
        echo(andRun ? "🚀 Building and running: \(options.scheme)" : "Building: \(options.scheme)")
        echo("   Workspace: \(options.workspace)")
        showDestination()
        if options.clean {
            echo("   Clean: yes")
        }
        echo()

        if options.dryRun {
            if options.clean {
                showCommand("xcodebuild clean", targetArguments)
                echo()
            }
            showCommand("xcodebuild build", (options.quiet ? ["-quiet"] : []) + targetArguments + ["2>&1 | xcbeautify"])
            if andRun {
                echo()
                if options.destinationType == "device" {
                    echo("\(yellow)# Then: install and launch on device\(reset)")
                    echo("\(yellow)xcrun devicectl device install app --device \"\(options.deviceID)\" <app-path>\(reset)")
                    echo("\(yellow)xcrun devicectl device process launch --device \"\(options.deviceID)\" <bundle-id>\(reset)")
                } else {
                    echo("\(yellow)# Then: boot simulator, install app, launch app\(reset)")
                }
            }
            return
        }

        try requireXcbeautify()

        if options.clean {
            echo("\(blue)Cleaning...\(reset)")
            if runClean() != 0 {
                echo("\(red)Clean failed\(reset)")
                playSound(1)
                throw ExitCode(1)
            }
            echo("\(green)Clean succeeded\(reset)")
            echo()
        }

        let logPath = buildLogPath()
        let status = try runBeautified(xcodebuild("build", quiet: options.quiet), logPath: logPath)

        if status != 0 {
            ErrorSummary.show(logPath: logPath)
            echo()
            if andRun {
                echo("\(red)❌ Build failed (exit code: \(status))\(reset)")
                echo()
                echo("\(cyan)📁 Build log:\(reset) \(logPath)")
            } else {
                echo("\(red)Build failed (exit code: \(status))\(reset)")
                echo("\(cyan)Build log:\(reset) \(logPath)")
            }
            playSound(status)
            throw ExitCode(status)
        }
        ErrorSummary.show(logPath: logPath)
        try? FileManager.default.removeItem(atPath: logPath)
        if options.quiet {
            echo("\(green)Build succeeded\(reset)")
        }

        guard andRun else {
            playSound(0)
            return
        }

        guard let app = resolveBuiltApp() else {
            echo("\(yellow)⚠ Could not determine app path. Build succeeded but cannot auto-launch.\(reset)")
            echo("\(yellow)  Make sure your scheme includes a runnable .app target.\(reset)")
            playSound(0)
            return
        }

        launch(app)
        playSound(0)
    }

    func runLastBuild() throws {
        echo("🚀 Launching last built app: \(options.scheme)")
        echo("   Workspace: \(options.workspace)")
        showDestination()
        echo()

        if options.dryRun {
            if options.destinationType == "device" {
                echo("\(yellow)# Install and launch on device\(reset)")
                echo("\(yellow)xcrun devicectl device install app --device \"\(options.deviceID)\" <app-path>\(reset)")
                echo("\(yellow)xcrun devicectl device process launch --device \"\(options.deviceID)\" <bundle-id>\(reset)")
            } else {
                echo("\(yellow)# Boot simulator, install last built app, launch app\(reset)")
                echo("\(yellow)xcrun simctl boot <device-id>\(reset)")
                echo("\(yellow)xcrun simctl install <device-id> <app-path>\(reset)")
                echo("\(yellow)xcrun simctl launch <device-id> <bundle-id>\(reset)")
            }
            return
        }

        echo("\(blue)🔍 Reading build settings...\(reset)")
        guard let app = resolveBuiltApp() else {
            echo("\(red)Error: Could not determine app path. Have you built the app yet?\(reset)")
            echo("\(yellow)Tip: Make sure your scheme builds a runnable .app target\(reset)")
            throw ExitCode(1)
        }

        guard isDirectory(app.path) else {
            echo("\(red)Error: App not found at \(app.path)\(reset)")
            echo("\(yellow)Tip: Run 'build run' first\(reset)")
            throw ExitCode(1)
        }

        // Show app info
        echo("\(cyan)📦 App:\(reset) \(basename(app.path))")
        if let built = modificationDate(app.path) {
            echo("\(cyan)📅 Built:\(reset) \(format(built, "yyyy-MM-dd HH:mm:ss"))")
        }
        echo()

        launch(app)
    }

    // MARK: - Launching

    struct BuiltApp {
        let path: String
        let bundleID: String?
    }

    /// Locate the scheme's .app product via -showBuildSettings (one call, since each is slow).
    /// The bundle id is read from the app's Info.plist rather than build settings, so
    /// multi-target schemes (e.g. app + embedded framework) don't pick up a sibling's id.
    func resolveBuiltApp() -> BuiltApp? {
        let settings = Shell.capture(xcodebuild("-showBuildSettings")).output
        guard let product = Parsers.appProduct(inBuildSettings: settings),
              !product.name.isEmpty, !product.directory.isEmpty else { return nil }
        let path = "\(product.directory)/\(product.name)"
        return BuiltApp(path: path, bundleID: bundleIdentifier(ofApp: path))
    }

    private func bundleIdentifier(ofApp path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: "\(path)/Info.plist"),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }

    private func launch(_ app: BuiltApp) {
        if options.destinationType == "device" {
            launchOnDevice(app)
        } else {
            launchOnSimulator(app)
        }
    }

    private func launchOnDevice(_ app: BuiltApp) {
        echo("📲 Installing app on device...")
        Shell.run(["xcrun", "devicectl", "device", "install", "app", "--device", options.deviceID, app.path])

        echo("🚀 Launching app on device...")
        if let bundleID = app.bundleID {
            Shell.run(["xcrun", "devicectl", "device", "process", "launch", "--device", options.deviceID, bundleID])
            echo()
            echo("\(green)✅ App launched: \(bundleID)\(reset)")
        } else {
            echo("\(yellow)⚠ App installed but could not determine bundle ID to launch\(reset)")
        }
    }

    private func launchOnSimulator(_ app: BuiltApp) {
        let simulatorID = options.simulatorID
        echo("📱 Launching simulator...")
        Shell.run(["xcrun", "simctl", "boot", simulatorID], discardStderr: true)
        Shell.run(["open", "-a", "Simulator"])

        // Wait for SpringBoard to be fully ready before installing/launching.
        // simctl boot returns before the simulator is interactive — launching too
        // early causes FBSOpenApplicationServiceErrorDomain/denied by service delegate.
        echo("⏳ Waiting for simulator to be ready...")
        Shell.run(["xcrun", "simctl", "bootstatus", simulatorID, "-b"], discardStderr: true)

        echo("📲 Installing app...")
        Shell.run(["xcrun", "simctl", "install", simulatorID, app.path])

        echo("🚀 Launching app...")
        if let bundleID = app.bundleID {
            Shell.run(["xcrun", "simctl", "launch", simulatorID, bundleID])
            echo()
            echo("\(green)✅ App launched: \(bundleID)\(reset)")
        } else {
            echo("\(yellow)⚠ App installed but could not determine bundle ID to launch\(reset)")
        }
    }
}
