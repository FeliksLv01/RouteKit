# RouteKit

[English](README.md)

RouteKit 是一个独立的 Swift URL 路由库，提供内置宏注册、路径参数、路由优先级、URL 拦截器、中间件以及同步和异步执行 API。

## 文档

- [在线文档](https://felikslv01.github.io/RouteKit/documentation/routekit/)
- [快速入门](Sources/RouteKit/RouteKit.docc/GettingStarted.md)
- [定义路由](Sources/RouteKit/RouteKit.docc/DefiningRoutes.md)
- [执行路由](Sources/RouteKit/RouteKit.docc/ExecutingRoutes.md)
- [拦截器和中间件](Sources/RouteKit/RouteKit.docc/InterceptorsAndMiddleware.md)
- [安装](Sources/RouteKit/RouteKit.docc/Installation.md)
- [DocC 首页](Sources/RouteKit/RouteKit.docc/RouteKit.md)

README 提供常用功能概览；DocC catalog 包含完整指南和自动生成的 API Reference。可以通过 GitHub Pages 在线阅读，也可以在 Xcode 中打开 package，然后选择 **Product > Build Documentation**。

## 环境要求

- iOS 13.0+
- Mac Catalyst 13.0+
- Swift 6.0+

RouteKit 的页面路由依赖 UIKit，不支持 macOS。内部 `RouteKitMacros` 子包声明的 macOS deployment target 只用于构建 Swift 编译器插件。

## Swift Package Manager

在 Xcode 的 Package Dependencies 中添加 RouteKit，或在 `Package.swift` 中声明：

```swift
dependencies: [
    .package(
        url: "https://github.com/FeliksLv01/RouteKit.git",
        from: "0.0.1"
    )
]
```

然后将 `RouteKit` library product 添加到 iOS target。SwiftPM 会自动构建库内置的宏 target。

## CocoaPods

```ruby
pod 'RouteKit'
```

如果私有 Specs 仓库中包含 `RouteKit`，请在 Podfile 中将私有源放在公共 Specs 源之前。

两种依赖方式下，业务代码都只需导入 RouteKit：

```swift
import RouteKit
```

`@Route` 的声明、实现和 CocoaPods 使用的预编译插件都包含在 RouteKit 中，不需要安装或配置 TKMacros。

## 配置

首次调用 `Router.open` 或 `Router.canOpen` 前，需要配置默认 URL scheme 和页面打开方式：

```swift
RouterConfig.scheme = "myapp"
RouterConfig.defaultOpenHandler = { viewController, context in
    navigationController.pushViewController(viewController, animated: true)
}
```

路由开始工作后，配置将被冻结。

## 页面路由

```swift
import RouteKit
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

`@Route` 会生成 `static func register()`，并把路由类型写入 `__DATA_CONST,__routekit`。RouteKit 会在第一次使用时扫描该 section，完成懒注册。

## Action 路由

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

异步入口会等待路由执行完成：

```swift
let handled = try await Router.open("session/logout")
```

## 路由模式

配置 `RouterConfig.scheme = "myapp"` 后：

| Pattern | Example | Description |
| --- | --- | --- |
| `profile/:id` | `myapp://profile/42` | 命名参数 |
| `docs/*` | `myapp://docs/readme` | 单段通配 |
| `flutter/**` | `myapp://flutter/home/detail` | 多段 catch-all |
| `file/:{name}.json` | `myapp://file/report.json` | 部分参数 |

显式传给 `Router.open(_:params:)` 的参数会覆盖 URL query 和路径参数中的同名值。

## 优先级

```swift
@Route(patterns: [
    .init("profile/*", priority: .low),
    .init("profile/settings", priority: .high),
])
```

匹配顺序为 `high`、`default`、`low`。优先级只决定匹配结果；高优先级 handler 返回 `false` 后，不会继续尝试低优先级 handler。

## 自定义注册

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

## 拦截器和中间件

`RouteURLInterceptor` 在路由匹配前执行，可以重写、处理或拒绝 URL。`RouteMiddleware` 在匹配后执行，可以包装全局或单个路由的响应链。

```swift
RouterConfig.urlInterceptors = [LegacyURLInterceptor()]
RouterConfig.middlewares = [AnalyticsMiddleware()]
```

单个路由可以通过 `static var middlewares` 声明自己的中间件。

## License

RouteKit 使用 MIT 许可证。
