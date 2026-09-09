import Foundation

struct RouteID: Hashable, Sendable {
    let rawValue: Int
}

@MainActor
final class RouterRuntime {
    static let shared = RouterRuntime()

    private enum RegistrationState {
        case idle
        case registering
        case registered
        case failed(any Error)
    }

    private struct RouteDefinition {
        let handlerType: any RouteHandler.Type
    }

    private struct RouteTable {
        let high: RouteTrie<RouteID>
        let normal: RouteTrie<RouteID>
        let low: RouteTrie<RouteID>
    }

    private final class InFlight {
        let handler: any RouteHandler
        var task: Task<Bool, Never>?

        init(handler: any RouteHandler) {
            self.handler = handler
        }
    }

    private var state: RegistrationState = .idle
    private var highBuilder = RouteTrieBuilder<RouteID>()
    private var normalBuilder = RouteTrieBuilder<RouteID>()
    private var lowBuilder = RouteTrieBuilder<RouteID>()
    private var definitions: [RouteID: RouteDefinition] = [:]
    private var routeTable: RouteTable?
    private var nextRouteID = 0
    private var inFlight: [UUID: InFlight] = [:]
    private var testRouteTypes: [any RouteHandler.Type]?
    private let maxURLInterceptorRewrites = 3

    private init() {}

    func register(pattern: String, priority: RoutePriority, handlerType: any RouteHandler.Type) {
        guard case .registering = state else {
            assertionFailure("Routes can only be registered during lazy registration")
            return
        }
        do {
            let components = try patternComponents(pattern)
            let routeID = RouteID(rawValue: nextRouteID)
            nextRouteID += 1
            definitions[routeID] = RouteDefinition(handlerType: handlerType)
            switch priority {
            case .high:
                highBuilder.register(routeID, at: components)
            case .default:
                normalBuilder.register(routeID, at: components)
            case .low:
                lowBuilder.register(routeID, at: components)
            }
        } catch {
            state = .failed(error)
        }
    }

    enum Resolution {
        case route(any RouteHandler.Type, RouteContext)
        case handled(Bool)
    }

    func resolve(_ input: any URLConvertible, params: [String: Any]) throws -> (any RouteHandler.Type, RouteContext) {
        guard case .route(let handlerType, let context) = try resolve(input, params: params, appliesURLInterceptors: false) else {
            throw RouteError.notFound(input.urlValue ?? URL(fileURLWithPath: ""))
        }
        return (handlerType, context)
    }

    func resolve(_ input: any URLConvertible, params: [String: Any], appliesURLInterceptors: Bool) throws -> Resolution {
        try ensureRegistered()
        var url = try routeURL(input)
        var params = params
        if appliesURLInterceptors {
            let intercepted = try applyURLInterceptors(originalURL: url, url: url, params: params, isDryRun: false)
            switch intercepted {
            case .route(let interceptedURL, let interceptedParams):
                url = interceptedURL
                params = interceptedParams
            case .handled(let handled):
                return .handled(handled)
            }
        }
        return try resolve(url: url, params: params)
    }

    private enum URLInterceptorResolution {
        case route(URL, [String: Any])
        case handled(Bool)
    }

    private func applyURLInterceptors(
        originalURL: URL,
        url: URL,
        params: [String: Any],
        isDryRun: Bool
    ) throws -> URLInterceptorResolution {
        guard !RouterConfig.urlInterceptors.isEmpty else {
            return .route(url, params)
        }

        var currentURL = url
        var currentParams = params

        for _ in 0..<maxURLInterceptorRewrites {
            var didRewrite = false
            interceptorLoop: for interceptor in RouterConfig.urlInterceptors {
                let request = RouteURLRequest(originalURL: originalURL, url: currentURL, params: currentParams, isDryRun: isDryRun)
                switch interceptor.intercept(request) {
                case .proceed:
                    continue
                case .rewrite(let rewrittenURL, let rewrittenParams):
                    currentURL = try routeURL(rewrittenURL)
                    if let rewrittenParams {
                        currentParams.merge(rewrittenParams) { _, explicit in explicit }
                    }
                    didRewrite = true
                    break interceptorLoop
                case .handled(let handled):
                    return .handled(handled)
                case .reject:
                    return .handled(false)
                }
            }
            if !didRewrite {
                return .route(currentURL, currentParams)
            }
        }

        throw RouteError.tooManyURLInterceptorRewrites(currentURL)
    }

    private func resolve(url: URL, params: [String: Any]) throws -> Resolution {
        let path = routePath(url)
        guard let (routeID, captured) = matchedRoute(path: path),
            let definition = definitions[routeID]
        else {
            throw RouteError.notFound(url)
        }
        var urlParams: [String: Any] = [:]
        for name in captured.allNames {
            urlParams[name] = captured.get(name)
        }
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.forEach { item in
            urlParams[item.name] = item.value ?? ""
        }
        urlParams.merge(params) { _, explicit in explicit }
        return .route(definition.handlerType, RouteContext(url: url, urlParams: urlParams))
    }

    func canResolve(_ input: any URLConvertible) -> Bool {
        do {
            try ensureRegistered()
            let url = try routeURL(input)
            let intercepted = try applyURLInterceptors(originalURL: url, url: url, params: [:], isDryRun: true)
            switch intercepted {
            case .route(let interceptedURL, let interceptedParams):
                switch try resolve(url: interceptedURL, params: interceptedParams) {
                case .route:
                    return true
                case .handled(let handled):
                    return handled
                }
            case .handled(let handled):
                return handled
            }
        } catch {
            return false
        }
    }

    func start(_ action: any ActionRoute, context: RouteContext) -> RouteExecution {
        let identifier = UUID()
        let record = InFlight(handler: action)
        inFlight[identifier] = record
        let task = Task { @MainActor [action] in
            defer { self.inFlight[identifier] = nil }
            do {
                return try await action.handle(with: context)
            } catch is CancellationError {
                return false
            } catch {
                RouterConfig.unhandledErrorHandler(error, context.url)
                return false
            }
        }
        record.task = task
        return RouteExecution(identifier: identifier, task: task)
    }

    func start(handler: any RouteHandler, operation: @escaping @MainActor () async -> Bool) -> RouteExecution {
        let identifier = UUID()
        let record = InFlight(handler: handler)
        inFlight[identifier] = record
        let task = Task { @MainActor in
            defer { self.inFlight[identifier] = nil }
            return await operation()
        }
        record.task = task
        return RouteExecution(identifier: identifier, task: task)
    }

    func cancel(identifier: UUID) {
        inFlight[identifier]?.task?.cancel()
    }

    func resetForTesting(routeTypes: [any RouteHandler.Type]) {
        inFlight.values.forEach { $0.task?.cancel() }
        inFlight = [:]
        state = .idle
        highBuilder = RouteTrieBuilder<RouteID>()
        normalBuilder = RouteTrieBuilder<RouteID>()
        lowBuilder = RouteTrieBuilder<RouteID>()
        definitions = [:]
        routeTable = nil
        nextRouteID = 0
        testRouteTypes = routeTypes
        RouterConfig.resetForTesting()
    }

    private func ensureRegistered() throws {
        switch state {
        case .registered:
            return
        case .registering:
            throw RouteError.registrationReentered
        case .failed(let error):
            throw error
        case .idle:
            break
        }
        state = .registering
        RouterConfig.freeze()
        let routeTypes = testRouteTypes ?? RouteSectionReader.routeTypes()
        for routeType in routeTypes {
            routeType.register()
            if case .failed(let error) = state { throw error }
        }
        routeTable = RouteTable(high: highBuilder.build(), normal: normalBuilder.build(), low: lowBuilder.build())
        state = .registered
    }

    private func routeURL(_ input: any URLConvertible) throws -> URL {
        guard let inputURL = input.urlValue else { throw RouteError.invalidURL(String(describing: input)) }
        var value = inputURL.absoluteString
        if !value.contains("://") {
            guard let scheme = RouterConfig.scheme, !scheme.isEmpty else { throw RouteError.missingDefaultScheme(value) }
            value = "\(scheme)://\(value.hasPrefix("/") ? String(value.dropFirst()) : value)"
        }
        value = RouterConfig.normalizer?.normalize(value) ?? value
        guard let url = URL(string: value), url.scheme != nil else { throw RouteError.invalidURL(value) }
        return url
    }

    private func patternComponents(_ pattern: String) throws -> [RoutePathComponent] {
        var value = pattern
        if !value.contains("://") {
            guard let scheme = RouterConfig.scheme, !scheme.isEmpty else { throw RouteError.missingDefaultScheme(value) }
            value = "\(scheme)://\(value.hasPrefix("/") ? String(value.dropFirst()) : value)"
        }
        value = RouterConfig.normalizer?.normalize(value) ?? value
        guard let separator = value.range(of: "://") else { throw RouteError.invalidPattern(pattern) }
        let scheme = String(value[..<separator.lowerBound]).lowercased()
        let remainder = value[separator.upperBound...].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let segments = remainder.split(separator: "/", omittingEmptySubsequences: true)
        guard let host = segments.first else { throw RouteError.invalidPattern(pattern) }
        return [.constant(scheme), RoutePathComponent(stringLiteral: String(host).lowercased())]
            + segments.dropFirst().map { RoutePathComponent(stringLiteral: String($0)) }
    }

    private func routePath(_ url: URL) -> [String] {
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        return [url.scheme?.lowercased() ?? "", url.host?.lowercased() ?? ""]
            + path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private func matchedRoute(path: [String]) -> (RouteID, RouteMatchParameters)? {
        guard let routeTable else { return nil }
        for router in [routeTable.high, routeTable.normal, routeTable.low] {
            var parameters = RouteMatchParameters()
            if let routeID = router.route(path: path, parameters: &parameters) {
                return (routeID, parameters)
            }
        }
        return nil
    }
}
