import Foundation

/// `select` and `setup`: pick defaults interactively and save them to `.xcbrc`.
extension App {
    func select(_ target: SelectTarget) throws {
        switch target {
        case .workspace: try selectWorkspace()
        case .scheme: try selectScheme()
        case .destination: try selectDestination()
        case .simulator: try selectSimulator()
        case .device: try selectDevice()
        }
    }

    /// Prompt for a 1-based choice; returns a 0-based index.
    private func pick(_ prompt: String, count: Int) throws -> Int {
        echo("\(cyan)\(prompt) [1-\(count)]:\(reset) ", terminator: "")
        guard let choice = readChoice(), choice.allSatisfy(\.isNumber), let number = Int(choice), (1...count).contains(number) else {
            echo("\(red)Invalid selection\(reset)")
            throw ExitCode(1)
        }
        return number - 1
    }

    private func save(_ key: String, _ value: String) throws {
        try config.set(key, value)
    }

    func selectWorkspace() throws {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: ".")) ?? []
        let workspaces = entries.filter { $0.hasSuffix(".xcworkspace") && isDirectory($0) }.sorted()

        if workspaces.isEmpty {
            echo("\(red)Error: No .xcworkspace found in current directory\(reset)")
            throw ExitCode(1)
        }

        echo()
        echo("\(bold)Available workspaces:\(reset)")
        for (index, workspace) in workspaces.enumerated() {
            if workspace == options.workspace {
                echo("  \(green)\(index + 1)) \(workspace) (current)\(reset)")
            } else {
                echo("  \(index + 1)) \(workspace)")
            }
        }
        echo()

        let selected = workspaces[try pick("Pick a workspace", count: workspaces.count)]
        try save("WORKSPACE", selected)
        options.workspace = selected
        echo("\(green)Default workspace set to: \(bold)\(selected)\(reset)")
    }

    func selectScheme() throws {
        if options.workspace.isEmpty {
            echo("\(red)Error: Workspace is not set\(reset)")
            echo("\(yellow)Tip: Run 'xcb select workspace' first\(reset)")
            throw ExitCode(1)
        }
        echo("\(blue)Fetching schemes from \(options.workspace) (resolving packages)...\(reset)")
        let listOutput = Shell.capture(["xcodebuild", "-workspace", options.workspace, "-list"]).output
        var schemes = Parsers.schemes(inList: listOutput)

        if !options.filter.isEmpty {
            schemes = schemes.filter { $0.localizedCaseInsensitiveContains(options.filter) }
            if schemes.isEmpty {
                echo("\(red)Error: No schemes matching '\(options.filter)' found in \(options.workspace)\(reset)")
                throw ExitCode(1)
            }
            echo("\(cyan)Filtered by:\(reset) \(options.filter)")
        } else if schemes.isEmpty {
            echo("\(red)Error: No schemes found in \(options.workspace)\(reset)")
            throw ExitCode(1)
        }

        echo()
        echo("\(bold)Available schemes:\(reset)")
        for (index, scheme) in schemes.enumerated() {
            if scheme == options.scheme {
                echo("  \(green)\(index + 1)) \(scheme) (current)\(reset)")
            } else {
                echo("  \(index + 1)) \(scheme)")
            }
        }
        echo()

        let selected = schemes[try pick("Pick a scheme", count: schemes.count)]
        try save("SCHEME", selected)
        options.scheme = selected
        echo("\(green)Default scheme set to: \(bold)\(selected)\(reset)")
    }

    func selectDestination() throws {
        echo()
        echo("\(bold)Select build destination:\(reset)")
        let current = " \(green)(current)\(reset)"
        echo("  1) Simulator\(options.destinationType == "simulator" ? current : "")")
        echo("  2) Device\(options.destinationType == "device" ? current : "")")
        echo()

        let selected = try pick("Pick a destination", count: 2) == 0 ? "simulator" : "device"
        try save("DESTINATION_TYPE", selected)
        options.destinationType = selected
        echo("\(green)Default destination set to: \(bold)\(selected)\(reset)")

        // Chain to the appropriate device/simulator picker
        if selected == "simulator" {
            try selectSimulator()
        } else {
            try selectDevice()
        }
    }

    func selectDevice() throws {
        echo("\(blue)Fetching available devices...\(reset)")

        let jsonPath = NSTemporaryDirectory() + "xcb-devices-\(ProcessInfo.processInfo.processIdentifier).json"
        defer { try? FileManager.default.removeItem(atPath: jsonPath) }
        Shell.capture(["xcrun", "devicectl", "list", "devices", "--json-output", jsonPath])

        let data = FileManager.default.contents(atPath: jsonPath) ?? Data()
        let devices = (try? Parsers.devices(inDevicectlJSON: data)) ?? []

        if devices.isEmpty {
            echo("\(red)Error: No connected iOS devices found\(reset)")
            echo("\(yellow)Tip: Connect a device via USB and enable Developer Mode\(reset)")
            throw ExitCode(1)
        }

        echo()
        echo("\(bold)Available devices:\(reset)")
        for (index, device) in devices.enumerated() {
            let current = device.id == options.deviceID ? " \(green)(current)\(reset)" : ""
            echo("  \(index + 1)) \(device.name) — \(device.model) (iOS \(device.os))\(current)")
        }
        echo()

        let selected = devices[try pick("Pick a device", count: devices.count)]
        try save("DESTINATION_TYPE", "device")
        try save("DEVICE_ID", selected.id)
        try save("DEVICE_NAME", selected.name)
        options.destinationType = "device"
        options.deviceID = selected.id
        options.deviceName = selected.name
        echo("\(green)Default device set to: \(bold)\(selected.name)\(reset) \(green)(\(selected.model), iOS \(selected.os))\(reset)")
    }

    func selectSimulator() throws {
        echo("\(blue)Fetching available simulators...\(reset)")
        let simctlOutput = Shell.capture(["xcrun", "simctl", "list", "devices", "available"]).output
        let simulators = Parsers.simulators(inSimctl: simctlOutput)

        if simulators.isEmpty {
            echo("\(red)Error: No simulators found\(reset)")
            throw ExitCode(1)
        }

        echo()
        echo("\(bold)Available simulators:\(reset)")
        for (index, simulator) in simulators.enumerated() {
            let current = simulator.id == options.simulatorID ? " \(green)(current)\(reset)" : ""
            echo("  \(index + 1)) \(simulator.name) (iOS \(simulator.os))\(current)")
        }
        echo()

        let selected = simulators[try pick("Pick a simulator", count: simulators.count)]
        try save("DESTINATION_TYPE", "simulator")
        try save("SIMULATOR_NAME", selected.name)
        try save("SIMULATOR_ID", selected.id)
        try save("SIMULATOR_OS", selected.os)
        // Remove legacy keys
        try save("IPHONE_NAME", "")
        try save("OS_VERSION", "")
        options.destinationType = "simulator"
        options.simulatorName = selected.name
        options.simulatorID = selected.id
        options.simulatorOS = selected.os
        echo("\(green)Default simulator set to: \(bold)\(selected.name)\(reset) \(green)(iOS \(selected.os))\(reset)")
    }
}
