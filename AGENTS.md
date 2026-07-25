# AGENTS.md

## 协作约定

0. `TKRouter` 必须同时支持 Swift Package Manager 和 CocoaPods；共享同一份 `Sources/TKRouter` 和 `Tests/TKRouterTests`。
1. `TKRouter` 是公开的 Swift URL 路由库，源码和文档不得包含业务仓库、内部域名或私有服务依赖。
2. 路由类型使用 TKMacros 提供的 `@Route`，自动发现 section 固定为 `__DATA_CONST,__tk_routes`。
3. `RouterConfig` 必须在第一次 `Router.open` 或 `Router.canOpen` 前完成配置。
4. 修改匹配、注册、优先级、拦截器或中间件行为时，必须同步补充 `Tests/TKRouterTests`。
5. xcodebuild 输出使用 xcbeautify，优先使用 `generic/platform=iOS` 真机架构验证。
6. pod/bundle 命令使用系统 Ruby 和 rbenv 环境，不在沙盒中执行。
7. 不提交生成的 xcodeproj 或 xcworkspace。
8. 新增 Swift 文件不添加文件头注释。

## Commit

使用英文 Conventional Commits，例如：

```text
feat(router): add route middleware
fix(router): preserve explicit URL parameters
```
