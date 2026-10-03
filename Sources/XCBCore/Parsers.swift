import Foundation

/// Parsers for the output of xcodebuild, simctl, and devicectl.
enum Parsers {
    /// Reads `xcodebuild -showBuildSettings` output and returns the product name and
    /// BUILT_PRODUCTS_DIR for the first target whose product name ends in .app.
    /// Each target block lists BUILT_PRODUCTS_DIR before FULL_PRODUCT_NAME, so we
    /// remember the most recent dir and return on the first matching .app name.
    static func appProduct(inBuildSettings output: String) -> (name: String, directory: String)? {
        var lastDir = ""
        for line in lines(output) {
            if let dir = buildSetting("BUILT_PRODUCTS_DIR", in: line) {
                lastDir = dir
            }
            if let name = buildSetting("FULL_PRODUCT_NAME", in: line), name.hasSuffix(".app") {
                return (name, lastDir)
            }
        }
        return nil
    }

    /// Value of an indented `    KEY = value` line, or nil if the line is a different key.
    private static func buildSetting(_ key: String, in line: Substring) -> String? {
        let trimmed = line.drop(while: \.isWhitespace)
        guard trimmed.startIndex != line.startIndex, trimmed.hasPrefix(key) else { return nil }
        let afterKey = trimmed.dropFirst(key.count).drop(while: \.isWhitespace)
        guard afterKey.first == "=" else { return nil }
        return String(afterKey.dropFirst().drop(while: \.isWhitespace))
    }

    /// Scheme names from `xcodebuild -list`: the indented lines following "Schemes:".
    static func schemes(inList output: String) -> [String] {
        var schemes: [String] = []
        var inSchemes = false
        for line in lines(output) {
            if inSchemes {
                if line.isEmpty { break }
                schemes.append(String(line.drop(while: \.isWhitespace)))
            } else if line.contains("Schemes:") {
                inSchemes = true
            }
        }
        return schemes
    }

    struct Simulator: Equatable {
        let name: String
        let id: String
        let os: String
    }

    /// iOS simulators from `xcrun simctl list devices available`.
    /// Section headers look like: "-- iOS 26.2 --"
    /// Device lines look like:   "    iPhone 17 (UUID) (Booted)"
    static func simulators(inSimctl output: String) -> [Simulator] {
        var simulators: [Simulator] = []
        var currentOS: String?
        for line in lines(output) {
            if let header = line.wholeMatch(of: #/-- iOS (.+) --/#) {
                currentOS = String(header.1)
            } else if line.hasPrefix("--") {
                currentOS = nil
            } else if let os = currentOS, let device = line.prefixMatch(of: #/\s+(.+) \(([A-F0-9-]{36})\)/#) {
                simulators.append(Simulator(name: String(device.1), id: String(device.2), os: os))
            }
        }
        return simulators
    }

    struct Device: Equatable {
        let name: String
        let id: String
        let model: String
        let os: String
    }

    /// Connected iOS devices from `xcrun devicectl list devices --json-output`.
    static func devices(inDevicectlJSON data: Data) throws -> [Device] {
        let list = try JSONDecoder().decode(DeviceList.self, from: data)
        return list.result.devices.compactMap { entry in
            guard entry.hardwareProperties?.platform == "iOS",
                  entry.connectionProperties?.transportType != nil else { return nil }
            let hardware = entry.hardwareProperties
            return Device(
                name: entry.deviceProperties?.name ?? "",
                id: hardware?.udid ?? "",
                model: hardware?.marketingName ?? hardware?.productType ?? "",
                os: entry.deviceProperties?.osVersionNumber ?? ""
            )
        }
    }

    private struct DeviceList: Decodable {
        struct Result: Decodable {
            let devices: [Entry]
        }
        struct Entry: Decodable {
            struct Hardware: Decodable {
                let platform: String?
                let udid: String?
                let marketingName: String?
                let productType: String?
            }
            struct Properties: Decodable {
                let name: String?
                let osVersionNumber: String?
            }
            struct Connection: Decodable {
                let transportType: String?
            }
            let hardwareProperties: Hardware?
            let deviceProperties: Properties?
            let connectionProperties: Connection?
        }
        let result: Result
    }
}
