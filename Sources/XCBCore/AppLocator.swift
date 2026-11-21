import CryptoKit
import Foundation

/// Finds a scheme's built .app without `xcodebuild -showBuildSettings`, which loads the
/// whole workspace first (over a minute on large workspaces).
///
/// It reads the scheme's Run action (build configuration and .app name) and finds the
/// DerivedData folder Xcode created for this exact workspace path, so worktrees of the
/// same repo never pick up each other's builds. Whenever the guess could be wrong it
/// returns nil, and the caller falls back to build settings.
struct AppLocator {
    /// Absolute workspace path, as passed to xcodebuild.
    let workspace: String
    let scheme: String
    /// Platform folder suffix: `iphonesimulator` or `iphoneos`.
    let platform: String
    var derivedDataRoot = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
    /// Xcode's preferences (`com.apple.dt.Xcode`).
    var xcodeDefaults: [String: Any] = UserDefaults.standard.persistentDomain(forName: "com.apple.dt.Xcode") ?? [:]
    var userName = NSUserName()

    struct LaunchProduct: Equatable {
        let configuration: String
        let name: String
    }

    func locate() -> String? {
        guard Self.usesDefaultBuildLocations(xcodeDefaults),
              let product = launchProduct(),
              let folder = derivedDataFolder() else { return nil }
        let app = "\(folder)/Build/Products/\(product.configuration)-\(platform)/\(product.name)"
        return FileManager.default.fileExists(atPath: "\(app)/Info.plist") ? app : nil
    }

    /// Custom DerivedData or build locations (Xcode → Settings → Locations) put products
    /// elsewhere, while an old build may still sit in the default folder.
    static func usesDefaultBuildLocations(_ defaults: [String: Any]) -> Bool {
        guard defaults["IDECustomDerivedDataLocation"] == nil else { return false }
        let style = defaults["IDEBuildLocationStyle"] as? String
        return style == nil || style == "Unique"
    }

    // MARK: - Scheme

    /// The scheme's Run action product. Nil if the scheme isn't found, doesn't launch an
    /// .app, or several schemes with this name disagree.
    func launchProduct() -> LaunchProduct? {
        fromSchemes(Self.launchProduct(inScheme:))
    }

    /// The scheme's default test plan. Nil if the scheme isn't found, its test plans
    /// can't be read, or several schemes with this name disagree.
    func testPlan() -> TestPlan? {
        fromSchemes(Self.testPlan(inScheme:))
    }

    /// What `parse` reads from every scheme file with this name, if they all agree.
    private func fromSchemes<T: Equatable>(_ parse: (Data) -> T?) -> T? {
        let values = schemeFiles().map { path in FileManager.default.contents(atPath: path).flatMap(parse) }
        guard let first = values.first, let value = first, values.allSatisfy({ $0 == value }) else { return nil }
        return value
    }

    enum TestPlan: Equatable {
        /// The scheme lists its test targets directly.
        case none
        case named(String)
    }

    /// The Test action's default test plan, e.g. `AllTests` for
    /// `<TestPlanReference reference = "container:AllTests.xctestplan" default = "YES">`.
    /// Nil when the scheme has test plans but none is marked as the default.
    static func testPlan(inScheme data: Data) -> TestPlan? {
        guard let document = try? XMLDocument(data: data) else { return nil }
        let references = ((try? document.nodes(forXPath: "/Scheme/TestAction/TestPlans/TestPlanReference")) ?? [])
            .compactMap { $0 as? XMLElement }
        guard !references.isEmpty else { return TestPlan.none }
        guard let reference = references.first(where: { $0.attribute(forName: "default")?.stringValue == "YES" })?
                .attribute(forName: "reference")?.stringValue,
              let colon = reference.firstIndex(of: ":") else { return nil }
        let file = String(reference[reference.index(after: colon)...])
        let name = ((file as NSString).lastPathComponent as NSString).deletingPathExtension
        return name.isEmpty ? nil : .named(name)
    }

    static func launchProduct(inScheme data: Data) -> LaunchProduct? {
        guard let document = try? XMLDocument(data: data),
              let launch = (try? document.nodes(forXPath: "/Scheme/LaunchAction"))?.first as? XMLElement,
              launch.attribute(forName: "askForAppToLaunch")?.stringValue != "YES",
              let configuration = launch.attribute(forName: "buildConfiguration")?.stringValue,
              !configuration.isEmpty,
              let reference = (try? launch.nodes(forXPath: "BuildableProductRunnable/BuildableReference"))?.first
                as? XMLElement,
              let name = reference.attribute(forName: "BuildableName")?.stringValue,
              name.hasSuffix(".app") else { return nil }
        return LaunchProduct(configuration: configuration, name: name)
    }

    /// Every `<scheme>.xcscheme` in the workspace and its top-level projects, shared or
    /// the current user's.
    func schemeFiles() -> [String] {
        let containers = [workspace] + Self.projects(inWorkspace: workspace)
        let folders = containers.flatMap { container in
            ["\(container)/xcshareddata/xcschemes", "\(container)/xcuserdata/\(userName).xcuserdatad/xcschemes"]
        }
        return folders
            .map { "\($0)/\(scheme).xcscheme" }
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    /// Project paths referenced by `contents.xcworkspacedata`, including inside groups.
    static func projects(inWorkspace workspace: String) -> [String] {
        let workspaceDir = (workspace as NSString).deletingLastPathComponent
        guard let data = FileManager.default.contents(atPath: "\(workspace)/contents.xcworkspacedata"),
              let document = try? XMLDocument(data: data),
              let root = document.rootElement() else { return [] }

        func resolve(_ location: String, base: String) -> String? {
            guard let colon = location.firstIndex(of: ":") else { return nil }
            let kind = location[..<colon]
            let path = String(location[location.index(after: colon)...])
            switch kind {
            case "group": return path.isEmpty ? base : (base as NSString).appendingPathComponent(path)
            case "container": return (workspaceDir as NSString).appendingPathComponent(path)
            case "absolute": return path
            default: return nil
            }
        }

        func walk(_ element: XMLElement, base: String) -> [String] {
            (element.children ?? []).compactMap { $0 as? XMLElement }.flatMap { child -> [String] in
                guard let location = child.attribute(forName: "location")?.stringValue,
                      let path = resolve(location, base: base) else { return [] }
                switch child.name {
                case "Group": return walk(child, base: path)
                case "FileRef": return path.hasSuffix(".xcodeproj") ? [(path as NSString).standardizingPath] : []
                default: return []
                }
            }
        }
        return walk(root, base: workspaceDir)
    }

    /// What the app's location depends on besides build settings: the contents of the
    /// scheme files (Run configuration and product) and Xcode's build location settings.
    /// A path saved in `AppPathCache` is only trusted while this stays the same. Contents
    /// rather than modification dates, so switching branches without changing the scheme
    /// doesn't cost a slow lookup.
    func fingerprint() -> String {
        let schemes = schemeFiles().sorted().map { path in
            let contents = FileManager.default.contents(atPath: path) ?? Data()
            return "\(path) \(SHA256.hash(data: contents).hex)"
        }
        let locations = xcodeDefaults.keys.filter(Self.isLocationSetting).sorted().map { key in
            "\(key)=\(xcodeDefaults[key].map { "\($0)" } ?? "")"
        }
        return SHA256.hash(data: Data((schemes + locations).joined(separator: "\n").utf8)).hex
    }

    /// Xcode → Settings → Locations: DerivedData and build folder settings.
    static func isLocationSetting(_ key: String) -> Bool {
        key == "IDEBuildLocationStyle" || key.hasPrefix("IDECustom") || key.hasPrefix("IDESharedBuild")
    }

    // MARK: - DerivedData

    /// The DerivedData folder whose `info.plist` names this workspace. An exact path match
    /// wins (that's the folder xcodebuild uses); otherwise the newest folder whose path
    /// resolves to the same place, e.g. through a symlink.
    func derivedDataFolder() -> String? {
        let resolved = Self.resolve(workspace)
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: derivedDataRoot)) ?? []
        var sameTarget: [(folder: String, accessed: Date)] = []
        for name in folders {
            let folder = "\(derivedDataRoot)/\(name)"
            guard let data = FileManager.default.contents(atPath: "\(folder)/info.plist"),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let path = plist["WorkspacePath"] as? String else { continue }
            if path == workspace { return folder }
            if Self.resolve(path) == resolved {
                let accessed = plist["LastAccessedDate"] as? Date ?? modificationDate("\(folder)/info.plist") ?? .distantPast
                sameTarget.append((folder, accessed))
            }
        }
        return sameTarget.max { $0.accessed < $1.accessed }?.folder
    }

    // MARK: - Test runs

    enum TestRunLookup: Equatable {
        case found(String)
        /// Nothing built for testing yet (with coverage, when `coverage` was asked for).
        case notBuilt
        /// Can't tell which file is right: custom build locations, or a scheme whose test
        /// plan can't be read. Building wouldn't change that.
        case unknown
    }

    /// The newest `.xctestrun` for this scheme's default test plan and platform, written by
    /// `build-for-testing` as `<Scheme>[_<TestPlan>]_<platform><sdk>[-<arch>].xctestrun`.
    /// The exact name is built from the scheme, so another scheme (`App_Staging` for `App`)
    /// or another test plan never matches. With `coverage`, only one built with code
    /// coverage counts, since coverage can't be turned on at run time.
    func testRun(coverage: Bool) -> TestRunLookup {
        guard Self.usesDefaultBuildLocations(xcodeDefaults), let plan = testPlan() else { return .unknown }
        guard let folder = derivedDataFolder() else { return .notBuilt }
        let products = "\(folder)/Build/Products"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: products)) ?? []
        let newest = names
            .filter { Self.isTestRun($0, scheme: scheme, plan: plan, platform: platform) }
            .map { "\(products)/\($0)" }
            .filter { !coverage || Self.testRunHasCoverage($0) }
            .max { (modificationDate($0) ?? .distantPast) < (modificationDate($1) ?? .distantPast) }
        return newest.map(TestRunLookup.found) ?? .notBuilt
    }

    /// Whether `name` is the `.xctestrun` for this scheme, test plan and platform: the exact
    /// prefix followed by the SDK version (`27.2`), so `iphoneos` never matches `iphonesimulator`.
    static func isTestRun(_ name: String, scheme: String, plan: TestPlan, platform: String) -> Bool {
        let prefix = switch plan {
        case .none: "\(scheme)_\(platform)"
        case .named(let plan): "\(scheme)_\(plan)_\(platform)"
        }
        guard name.hasPrefix(prefix), name.hasSuffix(".xctestrun") else { return false }
        return name.dropFirst(prefix.count).first?.isNumber == true
    }

    /// Whether a `.xctestrun` was built with code coverage. Xcode lists the instrumented
    /// binaries in a non-empty `CodeCoverageBuildableInfos` array (top level in format 2)
    /// and leaves the key out otherwise. It's searched at any depth to also cover older
    /// formats that keep settings per test target.
    static func testRunHasCoverage(_ path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return false }
        func search(_ value: Any) -> Bool {
            if let dictionary = value as? [String: Any] {
                if let infos = dictionary["CodeCoverageBuildableInfos"] as? [Any], !infos.isEmpty { return true }
                return dictionary.values.contains(where: search)
            }
            if let array = value as? [Any] { return array.contains(where: search) }
            return false
        }
        return search(plist)
    }

    private static func resolve(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
}

/// App paths found the slow way, so unusual setups only pay for `-showBuildSettings` once.
/// Keyed by workspace, scheme and platform. An entry is used only while its app exists and
/// the `AppLocator.fingerprint()` it was saved with still matches, so changing the scheme's
/// Run configuration or Xcode's build locations triggers a fresh lookup.
struct AppPathCache {
    var file = NSHomeDirectory() + "/Library/Caches/xcb/app-paths.json"

    struct Entry: Codable, Equatable {
        let path: String
        let fingerprint: String
    }

    static func key(workspace: String, scheme: String, platform: String) -> String {
        "\(workspace)|\(scheme)|\(platform)"
    }

    func path(for key: String, fingerprint: String) -> String? {
        guard let entry = load()[key], entry.fingerprint == fingerprint,
              FileManager.default.fileExists(atPath: "\(entry.path)/Info.plist") else { return nil }
        return entry.path
    }

    func store(_ path: String, for key: String, fingerprint: String) {
        var entries = load()
        entries[key] = Entry(path: path, fingerprint: fingerprint)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        let directory = (file as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: file), options: .atomic)
    }

    /// Entries in an older or unreadable format are dropped; they're refilled the slow way.
    private func load() -> [String: Entry] {
        guard let data = FileManager.default.contents(atPath: file),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return entries
    }
}

private extension Digest {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
