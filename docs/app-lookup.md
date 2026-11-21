# How xcb finds your app

`build run`, `run` and `log` need the path of the built `.app`, to install and launch it or to read its bundle ID. Asking xcodebuild for it (`xcodebuild -showBuildSettings`) loads the whole workspace first, which takes over a minute on large workspaces. So xcb looks for the app itself, and only asks xcodebuild when it can't be sure.

## Finding the app in DerivedData

xcb reads the scheme's Run action for the build configuration and app name, for example `Debug` and `MyApp.app`. It then finds the DerivedData folder Xcode created for your workspace and looks for:

```
~/Library/Developer/Xcode/DerivedData/<MyApp-hash>/Build/Products/<Configuration>-<platform>/<MyApp.app>
```

xcb picks the DerivedData folder whose `info.plist` names your exact workspace path. Each worktree of a repo has its own folder, so worktrees never launch each other's builds.

When this works, xcb prints:

```
🔍 Found MyApp.app in DerivedData
```

## When xcb reads build settings instead

xcb falls back to `xcodebuild -showBuildSettings` when it can't be sure it has the right app:

- A custom DerivedData or build location is set in Xcode → Settings → Locations, or in the workspace's own settings (File → Workspace Settings).
- The scheme file can't be found, for example because Xcode creates the scheme automatically. It also falls back when the scheme doesn't launch an app, or when schemes with the same name disagree.
- No build matches yet.

It says why:

```
🔍 Reading build settings (couldn't find the app in DerivedData)...
```

## Remembered paths

A path found through build settings is saved in `~/Library/Caches/xcb/app-paths.json`, so this only costs a slow lookup once. A saved path is used only while the app still exists and the scheme files and location settings haven't changed since it was saved. When xcb uses one, it says so:

```
📌 Using the app path saved from an earlier build settings lookup
   Pass --no-fast-app-lookup to look it up again
```

## Turning it off

xcb can't see build folders set in the project's build settings (`CONFIGURATION_BUILD_DIR` or `SYMROOT`). If your project uses them, or xcb ever launches the wrong app, turn the fast lookup off:

- `--no-fast-app-lookup` reads build settings for one run, and saves the result again.
- `FAST_APP_LOOKUP="0"` in `.xcbrc` makes that the default for the project.
- `--fast-app-lookup` turns it back on for one run when `.xcbrc` turns it off.

Without the fast lookup, xcb prints:

```
🔍 Reading build settings (fast app lookup is off)...
```
