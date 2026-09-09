# AGENTS.md

## Project rules

1. RouteKit must support both Swift Package Manager and CocoaPods. Both integrations must compile the same runtime sources from `Sources/RouteKit` and use the same integration tests from `Tests/RouteKitTests`.
2. RouteKit is an open-source Swift URL routing library. Source code, tests, and documentation must not reference private applications, internal domains, credentials, or proprietary service dependencies.
3. The runtime library supports iOS 13 and Mac Catalyst 13 or later. It does not support macOS because `PageRoute` depends on UIKit. The macOS platform in `Macros/Package.swift` applies only to the compiler-plugin host.
4. Route handlers use the bundled `@Route` macro. Automatic discovery uses the fixed Mach-O section `__DATA_CONST,__routekit`; keep the macro emission and `RouteSectionReader` in sync.
5. Keep macro declarations in `Macros/Sources/RouteKitMacro` and compiler-plugin implementations in `Macros/Sources/RouteKitMacros`.
6. After changing `Macros/Sources/RouteKitMacros`, run `./build.sh` and commit the refreshed `Prebuilt/RouteKitMacros` used by CocoaPods. Keep this binary tracked through Git LFS as configured in `.gitattributes`; never commit it as a regular Git blob.
7. Configure `RouterConfig` before the first call to `Router.open` or `Router.canOpen`; configuration is intentionally frozen after routing begins.
8. Changes to matching, registration, priority, interceptors, middleware, or route execution must include corresponding tests in `Tests/RouteKitTests`. Macro behavior changes must include tests in `Macros/Tests/RouteKitMacrosTests`.
9. Validate SwiftPM with a generic iOS device build and format xcodebuild output with xcbeautify. Run the iOS test suite on an available simulator and run `swift test` from `Macros` for macro expansion tests.
10. Validate CocoaPods changes with `pod lib lint RouteKit.podspec --allow-warnings`. Run pod and bundle commands with the system Ruby/rbenv environment outside the sandbox.
11. Keep `Package.swift`, `RouteKit.podspec`, README installation examples, the prebuilt macro name, and release tags consistent when changing package names or versions.
12. Do not commit generated Xcode projects, workspaces, DerivedData, or SwiftPM build directories.
13. Do not add file-header comments to new Swift files.
14. Keep `README.md` in English and maintain the equivalent Simplified Chinese documentation in `README.zh-CN.md` when public APIs, requirements, or installation steps change.
15. Document every public API with DocC-compatible comments. Keep the English guides in `Sources/RouteKit/RouteKit.docc` aligned with behavior, and validate documentation changes with an iOS `xcodebuild docbuild`.

## Commits

Use English Conventional Commits, for example:

```text
feat(router): add route middleware
fix(router): preserve explicit URL parameters
```
