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
        let products = schemeFiles().map { path in
            FileManager.default.contents(atPath: path).flatMap(Self.launchProduct(inScheme:))
        }
        guard let first = products.first, let product = first,
              products.allSatisfy({ $0 == product }) else { return nil }
        return product
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

    /// The newest `.xctestrun` for this scheme and platform, written by `build-for-testing`
    /// (`<Scheme>[_<TestPlan>]_<platform><sdk>-<arch>.xctestrun`). With `coverage`, only one
    /// built with code coverage counts, since coverage can't be turned on at run time.
    func testRun(coverage: Bool) -> String? {
        guard Self.usesDefaultBuildLocations(xcodeDefaults), let folder = derivedDataFolder() else { return nil }
        let products = "\(folder)/Build/Products"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: products)) ?? []
        return names
            .filter { $0.hasPrefix("\(scheme)_") && $0.hasSuffix(".xctestrun") && $0.contains("_\(platform)") }
            .map { "\(products)/\($0)" }
            .filter { !coverage || Self.testRunHasCoverage($0) }
            .max { (modificationDate($0) ?? .distantPast) < (modificationDate($1) ?? .distantPast) }
    }

    /// Whether a `.xctestrun` was built with code coverage (any test target has coverage settings).
    static func testRunHasCoverage(_ path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return false }
        func search(_ value: Any) -> Bool {
            if let dictionary = value as? [String: Any] {
                return dictionary.contains { key, value in key.localizedCaseInsensitiveContains("coverage") || search(value) }
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
/// Keyed by workspace, scheme and platform; an entry is used only while its app exists.
struct AppPathCache {
    var file = NSHomeDirectory() + "/Library/Caches/xcb/app-paths.json"

    static func key(workspace: String, scheme: String, platform: String) -> String {
        "\(workspace)|\(scheme)|\(platform)"
    }

    func path(for key: String) -> String? {
        guard let path = load()[key], FileManager.default.fileExists(atPath: "\(path)/Info.plist") else { return nil }
        return path
    }

    func store(_ path: String, for key: String) {
        var entries = load()
        entries[key] = path
        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
        else { return }
        let directory = (file as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: file), options: .atomic)
    }

    private func load() -> [String: String] {
        guard let data = FileManager.default.contents(atPath: file),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return [:] }
        return entries
    }
}
