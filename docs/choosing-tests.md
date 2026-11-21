# Choosing which tests run

`xcb test` and `xcb test coverage` run every test in the scheme. To run fewer, use `--only-testing` and `--skip-testing`. They work like xcodebuild's `-only-testing` and `-skip-testing`, and xcb passes each value straight through.

## Naming tests

Both options take a test identifier, `Target[/Class[/method]]`:

| Identifier | Runs or skips |
|---|---|
| `MyTests` | Every test in the `MyTests` test target |
| `MyTests/LoginTests` | One XCTest class or Swift Testing suite |
| `MyTests/LoginTests/testValidCredentials` | One XCTest method |
| `MyTests/LoginTests/validCredentials()` | One Swift Testing test |

The target is the test bundle's name, as it appears in the scheme's Test action or the test plan. The class is the `XCTestCase` subclass, or the type that holds Swift Testing tests.

### Swift Testing tests need parentheses

To pick a single Swift Testing test, add `()` after its name. Without them, xcodebuild doesn't match the test, and it doesn't warn you:

- `--only-testing` runs no tests and still reports success.
- `--skip-testing` runs the test anyway.

Quote the identifier, because shells treat the parentheses as syntax:

```bash
xcb test --only-testing "MyTests/LoginTests/validCredentials()"
```

XCTest methods don't need parentheses.

## Running only some tests

```bash
# One test target
xcb test --only-testing MyTests

# One class or suite
xcb test --only-testing MyTests/LoginTests

# One XCTest method
xcb test --only-testing MyTests/LoginTests/testValidCredentials
```

## Skipping tests

```bash
# Everything except the UI tests
xcb test --skip-testing MyAppUITests

# Everything except one slow class
xcb test --skip-testing MyTests/NetworkTests
```

## Repeating and combining

Both options can be given more than once, and each value becomes its own xcodebuild argument. With both, xcodebuild runs the `--only-testing` tests minus the `--skip-testing` ones:

```bash
# Two classes
xcb test --only-testing MyTests/LoginTests --only-testing MyTests/SignupTests

# A whole target except one class
xcb test --only-testing MyTests --skip-testing MyTests/NetworkTests
```

The header lists what you picked:

```
   Only: MyTests
   Skip: MyTests/NetworkTests
```

## xcodebuild's colon form

xcodebuild writes these options with a colon, `-only-testing:MyTests/LoginTests`. xcb accepts that form too, so you can paste an argument from an xcodebuild command:

```bash
xcb test --only-testing:MyTests/LoginTests
xcb test --skip-testing:MyAppUITests
```

## Where they apply

- `test` and `test coverage` pass them to `xcodebuild test`.
- With `--without-building`, they're passed to `xcodebuild test-without-building`. This is the fastest way to rerun one test.
- Other actions, and `test coverage --last-results`, don't run tests. There, xcb ignores both options and says so:

```
⚠ --only-testing is ignored in build action
```

## The old name

`--only-testing` was called `--only` before. `--only` still works the same way, so existing scripts keep working.
