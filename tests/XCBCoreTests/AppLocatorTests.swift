import Foundation
import Testing
@testable import XCBCore

/// Builds a throwaway repo layout and DerivedData folder on disk.
private final class Sandbox {
    let root: String
    let derivedData: String

    init() throws {
        root = (NSTemporaryDirectory() as NSString).appendingPathComponent("xcb-applocator-\(UUID().uuidString)")
        derivedData = "\(root)/DerivedData"
        try FileManager.default.createDirectory(atPath: derivedData, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(atPath: root) }

    func write(_ path: String, _ contents: String) throws {
        try FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// A repo checkout with `App.xcworkspace` → `App/App.xcodeproj` and a shared scheme.
    func repo(_ name: String, scheme: String = launchScheme()) throws -> String {
        let repo = "\(root)/\(name)"
        try write("\(repo)/App.xcworkspace/contents.xcworkspacedata", """
            <?xml version="1.0" encoding="UTF-8"?>
            <Workspace version = "1.0">
               <Group location = "group:Apps" name = "Apps">
                  <FileRef location = "group:App.xcodeproj"></FileRef>
               </Group>
               <FileRef location = "group:Docs"></FileRef>
            </Workspace>
            """)
        try write("\(repo)/Apps/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme", scheme)
        return "\(repo)/App.xcworkspace"
    }

    /// A DerivedData folder for `workspace` holding a built `<config>-<platform>/<app>`.
    @discardableResult
    func derivedData(
        for workspace: String, folder: String, app: String? = "App.app",
        configuration: String = "Debug", platform: String = "iphonesimulator", accessed: Date = Date()
    ) throws -> String {
        let dir = "\(derivedData)/\(folder)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let info: [String: Any] = ["WorkspacePath": workspace, "LastAccessedDate": accessed]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: URL(fileURLWithPath: "\(dir)/info.plist"))
        guard let app else { return dir }
        let appPath = "\(dir)/Build/Products/\(configuration)-\(platform)/\(app)"
        try write("\(appPath)/Info.plist", "<plist/>")
        return appPath
    }

    func locator(
        _ workspace: String, scheme: String = "App", platform: String = "iphonesimulator", defaults: [String: Any] = [:]
    ) -> AppLocator {
        var locator = AppLocator(workspace: workspace, scheme: scheme, platform: platform)
        locator.derivedDataRoot = derivedData
        locator.xcodeDefaults = defaults
        locator.userName = "tester"
        return locator
    }
}

private func launchScheme(
    configuration: String = "Debug", product: String = "App.app", extra: String = "", testPlans: String = ""
) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Scheme version = "1.7">
       <TestAction buildConfiguration = "Testing">\(testPlans)</TestAction>
       <LaunchAction buildConfiguration = "\(configuration)" \(extra)>
          <BuildableProductRunnable runnableDebuggingMode = "0">
             <BuildableReference BuildableName = "\(product)" BlueprintName = "App"
                ReferencedContainer = "container:App.xcodeproj"></BuildableReference>
          </BuildableProductRunnable>
       </LaunchAction>
       <ArchiveAction buildConfiguration = "Release"></ArchiveAction>
    </Scheme>
    """
}

@Suite struct AppLocatorTests {
    @Test func findsTheAppBuiltForThisWorkspace() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        let app = try sandbox.derivedData(for: workspace, folder: "App-aaaa")

        #expect(sandbox.locator(workspace).locate() == app)
    }

    @Test func eachWorktreeGetsItsOwnBuildEvenWithTheSameAppName() throws {
        let sandbox = try Sandbox()
        let tree1 = try sandbox.repo("repo-tree1")
        let tree2 = try sandbox.repo("repo-tree2")
        let app1 = try sandbox.derivedData(for: tree1, folder: "App-aaaa", accessed: .distantPast)
        let app2 = try sandbox.derivedData(for: tree2, folder: "App-bbbb", accessed: Date())

        #expect(sandbox.locator(tree1).locate() == app1)
        #expect(sandbox.locator(tree2).locate() == app2)
    }

    @Test func neverFallsBackToAnotherWorktreesBuild() throws {
        let sandbox = try Sandbox()
        let tree1 = try sandbox.repo("repo-tree1")
        let tree2 = try sandbox.repo("repo-tree2")
        try sandbox.derivedData(for: tree2, folder: "App-bbbb")

        #expect(sandbox.locator(tree1).locate() == nil)
    }

    @Test func usesTheRunActionConfigurationAndDestinationPlatform() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo", scheme: launchScheme(configuration: "Debug-Staging"))
        try sandbox.derivedData(for: workspace, folder: "App-aaaa", configuration: "Debug")
        let device = try sandbox.derivedData(
            for: workspace, folder: "App-aaaa", configuration: "Debug-Staging", platform: "iphoneos")
        let simulator = try sandbox.derivedData(for: workspace, folder: "App-aaaa", configuration: "Debug-Staging")

        #expect(sandbox.locator(workspace).locate() == simulator)
        #expect(sandbox.locator(workspace, platform: "iphoneos").locate() == device)
    }

    @Test func returnsNilWhenTheAppHasNotBeenBuilt() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        try sandbox.derivedData(for: workspace, folder: "App-aaaa", app: nil)

        #expect(sandbox.locator(workspace).locate() == nil)
    }

    @Test func matchesAWorkspaceOpenedThroughASymlink() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        try FileManager.default.createSymbolicLink(atPath: "\(sandbox.root)/link", withDestinationPath: "\(sandbox.root)/repo")
        let app = try sandbox.derivedData(for: workspace, folder: "App-aaaa")

        #expect(sandbox.locator("\(sandbox.root)/link/App.xcworkspace").locate() == app)
    }

    @Test func prefersTheExactPathThenTheNewestFolderForTheSameWorkspace() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        let link = "\(sandbox.root)/link"
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: "\(sandbox.root)/repo")
        let exact = try sandbox.derivedData(for: workspace, folder: "App-aaaa", accessed: .distantPast)
        let viaLink = try sandbox.derivedData(for: "\(link)/App.xcworkspace", folder: "App-bbbb", accessed: Date())

        #expect(sandbox.locator(workspace).locate() == exact)
        try FileManager.default.removeItem(atPath: "\(sandbox.derivedData)/App-aaaa")
        #expect(sandbox.locator(workspace).locate() == viaLink)
    }

    @Test func stepsAsideForCustomBuildLocations() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        try sandbox.derivedData(for: workspace, folder: "App-aaaa")

        #expect(sandbox.locator(workspace, defaults: ["IDEBuildLocationStyle": "Unique"]).locate() != nil)
        #expect(sandbox.locator(workspace, defaults: ["IDECustomDerivedDataLocation": "/Volumes/DD"]).locate() == nil)
        #expect(sandbox.locator(workspace, defaults: ["IDEBuildLocationStyle": "Custom"]).locate() == nil)
        #expect(sandbox.locator(workspace, defaults: ["IDEBuildLocationStyle": "DeterminedByTargets"]).locate() == nil)
    }

    @Test func stepsAsideWhenSchemesWithTheSameNameDisagree() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        try sandbox.derivedData(for: workspace, folder: "App-aaaa")
        try sandbox.write(
            "\(sandbox.root)/repo/App.xcworkspace/xcuserdata/tester.xcuserdatad/xcschemes/App.xcscheme",
            launchScheme(product: "Other.app"))

        #expect(sandbox.locator(workspace).locate() == nil)
    }
}

@Suite struct TestRunLookupTests {
    private func writeTestRun(_ sandbox: Sandbox, folder: String, name: String, coverage: Bool, modified: Date) throws -> String {
        let path = "\(sandbox.derivedData)/\(folder)/Build/Products/\(name)"
        // Format 2, as Xcode writes it: coverage builds list the instrumented binaries at the top level.
        var plist: [String: Any] = [
            "__xctestrun_metadata__": ["FormatVersion": 2],
            "TestConfigurations": [["Name": "Test Scheme Action", "TestTargets": [["BlueprintName": "AppTests"]]]],
        ]
        if coverage { plist["CodeCoverageBuildableInfos"] = [["Name": "App.app"]] }
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: path)
        return path
    }

    @Test(arguments: [
        ("top-level list", true),
        ("per-target list (older formats)", true),
        ("no key", false),
        ("empty list", false),
        ("other coverage-named keys", false),
    ])
    func coverageMeansANonEmptyBuildableInfosList(layout: String, expected: Bool) throws {
        let infos: [[String: Any]] = [["Name": "App.app"]]
        let body: [String: Any] = switch layout {
        case "top-level list": ["CodeCoverageBuildableInfos": infos]
        case "per-target list (older formats)": ["AppTests": ["CodeCoverageBuildableInfos": infos]]
        case "empty list": ["CodeCoverageBuildableInfos": [Any]()]
        case "other coverage-named keys": ["AppTests": ["EnableCodeCoverage": false, "CodeCoverageSettings": ["Enabled": false]]]
        default: [:]
        }
        let sandbox = try Sandbox()
        let path = "\(sandbox.root)/App.xctestrun"
        let plist = body.merging(["__xctestrun_metadata__": ["FormatVersion": 2]]) { current, _ in current }
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: URL(fileURLWithPath: path))

        #expect(AppLocator.testRunHasCoverage(path) == expected)
    }

    private func plans(_ plans: [(name: String, isDefault: Bool)]) -> String {
        "<TestPlans>" + plans.map { plan in
            #"<TestPlanReference reference = "container:Plans/\#(plan.name).xctestplan"\#(plan.isDefault ? #" default = "YES""# : "")></TestPlanReference>"#
        }.joined() + "</TestPlans>"
    }

    @Test func findsTheNewestTestRunForTheSchemeAndPlatform() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        try sandbox.derivedData(for: workspace, folder: "App-aaaa", app: nil)
        _ = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_iphonesimulator26.0-arm64.xctestrun", coverage: false, modified: .distantPast)
        let newest = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_iphonesimulator27.2-arm64.xctestrun", coverage: false, modified: Date(timeIntervalSinceNow: -60))
        let device = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_iphoneos27.2-arm64.xctestrun", coverage: false, modified: Date())
        _ = try writeTestRun(sandbox, folder: "App-aaaa", name: "Other_iphonesimulator27.2-arm64.xctestrun", coverage: false, modified: Date())

        #expect(sandbox.locator(workspace).testRun(coverage: false) == .found(newest))
        #expect(sandbox.locator(workspace, platform: "iphoneos").testRun(coverage: false) == .found(device))
    }

    @Test func neverPicksASchemeWhoseNameStartsTheSame() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        try sandbox.derivedData(for: workspace, folder: "App-aaaa", app: nil)
        let app = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_iphonesimulator27.2.xctestrun", coverage: false, modified: .distantPast)
        _ = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_Staging_iphonesimulator27.2.xctestrun", coverage: false, modified: Date())

        #expect(sandbox.locator(workspace).testRun(coverage: false) == .found(app))
    }

    @Test func usesTheSchemesDefaultTestPlan() throws {
        let sandbox = try Sandbox()
        let scheme = launchScheme(testPlans: plans([("UI", false), ("Unit", true)]))
        let workspace = try sandbox.repo("repo", scheme: scheme)
        try sandbox.derivedData(for: workspace, folder: "App-aaaa", app: nil)
        let unit = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_Unit_iphonesimulator27.2-arm64.xctestrun", coverage: false, modified: .distantPast)
        _ = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_UI_iphonesimulator27.2-arm64.xctestrun", coverage: false, modified: Date())

        #expect(sandbox.locator(workspace).testRun(coverage: false) == .found(unit))
    }

    @Test func isNotBuiltUntilThereIsAMatchingTestRun() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        #expect(sandbox.locator(workspace).testRun(coverage: false) == .notBuilt)  // no DerivedData folder

        try sandbox.derivedData(for: workspace, folder: "App-aaaa", app: nil)
        _ = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_Staging_iphonesimulator27.2.xctestrun", coverage: false, modified: Date())
        #expect(sandbox.locator(workspace).testRun(coverage: false) == .notBuilt)
    }

    @Test func isUnknownWhenTheRightFileCannotBeWorkedOut() throws {
        let sandbox = try Sandbox()
        let noDefault = try sandbox.repo("no-default", scheme: launchScheme(testPlans: plans([("Unit", false), ("UI", false)])))
        let standard = try sandbox.repo("repo")
        for workspace in [noDefault, standard] {
            try sandbox.derivedData(for: workspace, folder: "App-\(UUID().uuidString)", app: nil)
        }

        #expect(sandbox.locator(noDefault).testRun(coverage: false) == .unknown)
        #expect(sandbox.locator(standard, defaults: ["IDECustomDerivedDataLocation": "/Volumes/DD"]).testRun(coverage: false) == .unknown)
        #expect(sandbox.locator(standard, scheme: "Missing").testRun(coverage: false) == .unknown)
    }

    @Test func coverageRunsOnlyUseTestRunsBuiltWithCoverage() throws {
        let sandbox = try Sandbox()
        let workspace = try sandbox.repo("repo")
        try sandbox.derivedData(for: workspace, folder: "App-aaaa", app: nil)
        let plain = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_iphonesimulator27.2-arm64.xctestrun", coverage: false, modified: Date())

        #expect(sandbox.locator(workspace).testRun(coverage: true) == .notBuilt)
        #expect(sandbox.locator(workspace).testRun(coverage: false) == .found(plain))

        let covered = try writeTestRun(sandbox, folder: "App-aaaa", name: "App_iphonesimulator27.2-arm64.xctestrun", coverage: true, modified: Date())
        #expect(sandbox.locator(workspace).testRun(coverage: true) == .found(covered))
    }

    @Test func ignoresOtherWorktreesTestRuns() throws {
        let sandbox = try Sandbox()
        let tree1 = try sandbox.repo("repo-tree1")
        let tree2 = try sandbox.repo("repo-tree2")
        try sandbox.derivedData(for: tree2, folder: "App-bbbb", app: nil)
        _ = try writeTestRun(sandbox, folder: "App-bbbb", name: "App_iphonesimulator27.2-arm64.xctestrun", coverage: true, modified: Date())

        #expect(sandbox.locator(tree1).testRun(coverage: false) == .notBuilt)
    }

    @Test(arguments: [
        ("App_iphonesimulator27.2.xctestrun", AppLocator.TestPlan.none, "iphonesimulator", true),
        ("App_iphonesimulator27.2-arm64.xctestrun", .none, "iphonesimulator", true),
        ("App_iphoneos27.2-arm64.xctestrun", .none, "iphoneos", true),
        ("App_iphoneos27.2-arm64.xctestrun", .none, "iphonesimulator", false),
        ("App_Staging_iphonesimulator27.2.xctestrun", .none, "iphonesimulator", false),
        ("App_Unit_iphonesimulator27.2.xctestrun", .named("Unit"), "iphonesimulator", true),
        ("App_UI_iphonesimulator27.2.xctestrun", .named("Unit"), "iphonesimulator", false),
        ("App_Unit_iphonesimulator27.2.xctestrun", .none, "iphonesimulator", false),
        ("App_iphonesimulator27.2.xctestrun.bak", .none, "iphonesimulator", false),
    ])
    func matchesTheExactTestRunName(name: String, plan: AppLocator.TestPlan, platform: String, expected: Bool) {
        #expect(AppLocator.isTestRun(name, scheme: "App", plan: plan, platform: platform) == expected)
    }

    @Test func readsTheDefaultTestPlanFromTheScheme() {
        func plan(_ scheme: String) -> AppLocator.TestPlan? { AppLocator.testPlan(inScheme: Data(scheme.utf8)) }

        #expect(plan(launchScheme()) == AppLocator.TestPlan.none)
        #expect(plan(launchScheme(testPlans: plans([("UI", false), ("AllTests", true)]))) == .named("AllTests"))
        #expect(plan(launchScheme(testPlans: plans([("Unit", false)]))) == nil)
        #expect(plan("not xml") == nil)
    }
}

@Suite struct SchemeLaunchProductTests {
    private func product(_ scheme: String) -> AppLocator.LaunchProduct? {
        AppLocator.launchProduct(inScheme: Data(scheme.utf8))
    }

    @Test func readsTheRunActionNotOtherActions() {
        #expect(product(launchScheme()) == .init(configuration: "Debug", name: "App.app"))
    }

    @Test func ignoresSchemesThatDoNotLaunchAnApp() {
        #expect(product(launchScheme(product: "Widget.appex")) == nil)
        #expect(product(launchScheme(extra: #"askForAppToLaunch = "YES""#)) == nil)
        #expect(product("""
            <Scheme><LaunchAction buildConfiguration = "Debug">
               <PathRunnable FilePath = "/Applications/Safari.app"></PathRunnable>
            </LaunchAction></Scheme>
            """) == nil)
        #expect(product("not xml") == nil)
    }
}

@Suite struct WorkspaceProjectsTests {
    @Test func resolvesGroupContainerAndAbsoluteLocations() throws {
        let sandbox = try Sandbox()
        let workspace = "\(sandbox.root)/repo/Main.xcworkspace"
        try sandbox.write("\(workspace)/contents.xcworkspacedata", """
            <Workspace version = "1.0">
               <FileRef location = "group:markets/usa/Walmart.xcodeproj"></FileRef>
               <Group location = "group:Platform" name = "Platform">
                  <Group location = "group:Kit" name = "Kit">
                     <FileRef location = "group:Kit.xcodeproj"></FileRef>
                  </Group>
                  <FileRef location = "container:Tools/Tools.xcodeproj"></FileRef>
               </Group>
               <FileRef location = "absolute:/opt/Shared/Shared.xcodeproj"></FileRef>
               <FileRef location = "group:docs"></FileRef>
            </Workspace>
            """)

        #expect(AppLocator.projects(inWorkspace: workspace) == [
            "\(sandbox.root)/repo/markets/usa/Walmart.xcodeproj",
            "\(sandbox.root)/repo/Platform/Kit/Kit.xcodeproj",
            "\(sandbox.root)/repo/Tools/Tools.xcodeproj",
            "/opt/Shared/Shared.xcodeproj",
        ])
    }
}

@Suite struct AppPathCacheTests {
    @Test func remembersAppsWhileTheyExist() throws {
        let sandbox = try Sandbox()
        let cache = AppPathCache(file: "\(sandbox.root)/cache/app-paths.json")
        let app = "\(sandbox.root)/Products/App.app"
        let key = AppPathCache.key(workspace: "/repo/App.xcworkspace", scheme: "App", platform: "iphonesimulator")

        cache.store(app, for: key)
        #expect(cache.path(for: key) == nil)  // not built yet

        try sandbox.write("\(app)/Info.plist", "<plist/>")
        #expect(cache.path(for: key) == app)
        #expect(cache.path(for: AppPathCache.key(workspace: "/other/App.xcworkspace", scheme: "App", platform: "iphonesimulator")) == nil)
    }
}
