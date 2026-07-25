# TKRouter

TKRouter 是一个 Swift URL 路由库，提供宏注册、路径参数、优先级、URL 拦截器、中间件以及同步/异步路由执行。

## Requirements

- iOS 13.0+
- Swift 6.0+
- TKMacros 0.0.4+

## Swift Package Manager

在 Xcode 的 Package Dependencies 中添加：

```text
https://github.com/TokenTeamiOS/TKRouter.git
```

或在 `Package.swift` 中声明：

```swift
dependencies: [
    .package(
        url: "https://github.com/TokenTeamiOS/TKRouter.git",
        from: "0.1.0"
    )
]
```

然后将 `TKRouter` library product 添加到 iOS target。SwiftPM 会自动解析并构建 TKMacros 的原生 macro target。

## CocoaPods

```ruby
pod 'TKRouter'
```

两种依赖方式下，TKRouter 都会依赖并 re-export TKMacros，业务代码只需导入 TKRouter：

```swift
import TKRouter
```

使用 CocoaPods 时，如果 Pod target 无法展开间接依赖中的宏，请在 Podfile 中加载 TKMacros 提供的 Swift flags 脚本：

```ruby
require_relative 'Pods/TKMacros/Scripts/tk_swift_flags'

post_install do |installer|
  inject_tk_swift_flags_if_needed(installer)
end
```

## Configuration

首次打开路由前配置默认 scheme 和页面打开方式：

```swift
RouterConfig.scheme = "myapp"
RouterConfig.defaultOpenHandler = { viewController, context in
    navigationController.pushViewController(viewController, animated: true)
}
```

配置在第一次 `Router.open` 或 `Router.canOpen` 后冻结。

## Page Route

```swift
import TKRouter
import UIKit

@Route(patterns: [
    .init("profile/:id"),
    .init("profile/settings", priority: .high),
])
struct ProfileRoute: PageRoute {
    func destination(with context: RouteContext) -> UIViewController? {
        guard let id = context.urlParams["id"] as? String else {
            return nil
        }
        return ProfileViewController(id: id)
    }
}
```

`@Route` 会生成 `static func register()`，并把路由类型写入 `__DATA_CONST,__tk_routes`。TKRouter 在第一次使用时扫描 section 并完成懒注册。

## Action Route

```swift
@Route(patterns: [
    .init("session/logout")
])
struct LogoutRoute: ActionRoute {
    func handle(with context: RouteContext) async throws -> Bool {
        await session.logout()
        return true
    }
}
```

同步入口会立即返回 `RouteExecution`：

```swift
let execution = Router.open("session/logout")
let handled = await execution?.result
execution?.cancel()
```

异步入口会等待路由完成：

```swift
let handled = try await Router.open("session/logout")
```

## Patterns

在配置了 `RouterConfig.scheme = "myapp"` 后：

| Pattern | Example | Description |
| --- | --- | --- |
| `profile/:id` | `myapp://profile/42` | 命名参数 |
| `docs/*` | `myapp://docs/readme` | 单段通配 |
| `flutter/**` | `myapp://flutter/home/detail` | 多段 catch-all |
| `file/:{name}.json` | `myapp://file/report.json` | 部分参数 |

显式传给 `Router.open(_:params:)` 的参数会覆盖 URL query 和路径参数中的同名值。

## Priority

```swift
@Route(patterns: [
    .init("profile/*", priority: .low),
    .init("profile/settings", priority: .high),
])
```

匹配顺序为 high、default、low。优先级只决定匹配结果，不会在高优先级 handler 返回 `false` 后继续尝试低优先级 handler。

## Custom Registration

需要动态 pattern 时使用无参宏：

```swift
@Route
struct DynamicRoute: ActionRoute {
    static func register() {
        register(RouteConfiguration.dynamicPattern)
    }

    func handle(with context: RouteContext) async throws -> Bool {
        true
    }
}
```

## Interceptors and Middleware

`RouteURLInterceptor` 在路由匹配前执行，可重写、处理或拒绝 URL。`RouteMiddleware` 在匹配后执行，可包装全局或单个 handler 的响应链。

```swift
RouterConfig.urlInterceptors = [LegacyURLInterceptor()]
RouterConfig.middlewares = [AnalyticsMiddleware()]
```

单个路由可通过 `static var middlewares` 声明自己的中间件。

## License

TKRouter is available under the MIT license.
