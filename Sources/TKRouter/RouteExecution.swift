import Foundation

@MainActor
public final class RouteExecution {
    let identifier: UUID?
    private let task: Task<Bool, Never>?
    private let immediateResult: Bool

    init(identifier: UUID?, immediateResult: Bool = false, task: Task<Bool, Never>? = nil) {
        self.identifier = identifier
        self.immediateResult = immediateResult
        self.task = task
    }

    public var result: Bool {
        get async {
            guard let task else { return immediateResult }
            return await task.value
        }
    }

    public func cancel() {
        guard let identifier else { return }
        RouterRuntime.shared.cancel(identifier: identifier)
    }
}
