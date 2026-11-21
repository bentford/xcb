# Rerunning tests without building

`xcb test --without-building` reruns tests from your last build, like Xcode's Test Without Building. It skips loading the workspace and compiling, so rerunning one test on a large workspace takes seconds instead of minutes.

```bash
xcb test --only-testing MyTests/LoginTests/testValidCredentials --without-building
```

It pairs well with `--only-testing` and `--skip-testing`; see [Choosing which tests run](choosing-tests.md).

## How it works

When Xcode builds for testing, it writes a `.xctestrun` file next to the build products. It lists the test bundles and how to run them. xcb finds that file in the DerivedData folder Xcode created for your workspace:

```
~/Library/Developer/Xcode/DerivedData/<MyApp-hash>/Build/Products/<Scheme>[_<TestPlan>]_<platform><version>.xctestrun
```

It picks the newest one for the scheme's default test plan and the destination's platform, then runs `xcodebuild test-without-building -xctestrun <file>`. The header shows which file it used:

```
   Build: skipped, using the last build for testing (builds once if there isn't one)
   Test run: MyApp_AllTests_iphonesimulator27.2.xctestrun
```

Because the workspace isn't loaded, xcodebuild doesn't resolve packages either, so `--skip-package-updates` has no effect here.

## What gets tested

It runs whatever was built last, so code changes since then aren't included. Run `xcb test` without the option to build and test your latest changes. Each `xcb test` run updates the test bundles, so a later `--without-building` run uses them.

## The first run

If there's no `.xctestrun` yet, xcb builds for testing once (`xcodebuild build-for-testing`) and then runs the tests from it:

```
🔨 No build for testing yet. Building once so later runs can skip the build...
```

## With coverage

Code coverage is set when tests are built, and can't be turned on when they run. So `xcb test coverage --without-building` only uses a `.xctestrun` built with coverage. If there isn't one, it builds one the first time, like above.

## When xcb can't find the right file

xcb can't tell which `.xctestrun` to use when:

- a custom DerivedData or build location is set in Xcode → Settings → Locations, or in the workspace's settings, or
- it can't read the scheme's test plan, for example because Xcode creates the scheme automatically.

Then it lets xcodebuild find the build through the scheme instead. That loads the workspace, so it's slower, but it still doesn't build:

```
⚠ Couldn't tell which .xctestrun to use; running from the scheme instead
```

## Where it applies

`--without-building` works with `test` and `test coverage`. Other actions, and `test coverage --last-results`, don't run tests, so xcb ignores it and says so:

```
⚠ --without-building is ignored in build action
```
