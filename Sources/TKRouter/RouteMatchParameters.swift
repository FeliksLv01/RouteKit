import Foundation

/// Captured dynamic parameters from a route match.
struct RouteMatchParameters: Sendable {
    private var values: [String: String]
    private var catchall: [String]

    var allNames: Set<String> { .init(self.values.keys) }

    init() {
        self.values = [:]
        self.catchall = []
    }

    func get(_ name: String) -> String? {
        self.values[name]
    }

    mutating func set(_ name: String, to value: String?) {
        self.values[name] = value.map { $0.removingPercentEncoding ?? $0 }
    }

    mutating func setCatchall(matched: [String]) {
        self.catchall = matched.map { $0.removingPercentEncoding ?? $0 }
    }
}
