import Testing
@testable import XCBCore

@Suite struct UpdaterTests {
    @Test(arguments: [
        ("https://github.com/bentford/xcb/releases/tag/v0.2.0", "0.2.0"),
        ("https://github.com/bentford/xcb/releases/tag/0.2.0\n", "0.2.0"),
        ("https://github.com/bentford/xcb/releases/tag/v1.10.3-beta", "1.10.3-beta"),
    ])
    func readsVersionFromTagURL(url: String, expected: String) {
        #expect(Updater.releaseVersion(fromTagURL: url) == expected)
    }

    @Test(arguments: [
        "https://github.com/bentford/xcb/releases",
        "https://github.com/bentford/xcb/releases/tag/",
        "",
    ])
    func rejectsNonTagURLs(url: String) {
        #expect(Updater.releaseVersion(fromTagURL: url) == nil)
    }
}
