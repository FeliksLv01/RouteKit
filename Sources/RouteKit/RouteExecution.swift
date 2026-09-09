import Foundation

@MainActor
/// A handle for an in-flight or already completed route operation.
public final class RouteExecution {
    let identifier: UUID?
    private let task: Task<Bool, Never>?
    private let immediateResult: Bool

    init(identifier: UUID?, immediateResult: Bool = false, task: Task<Bool, Never>? = nil) {
        self.identifier = identifier
        self.immediateResult = immediateResult
        self.task = task
    }

    /// The final handled state of the route operation.
    ///
    /// Reading this property suspends until asynchronous route work finishes.
    public var result: Bool {
        get async {
            guard let task else { return immediateResult }
            return await task.value
        }
    }

    /// Cancels the underlying asynchronous route operation.
    ///
    /// Calling this method after completion, or for an immediate result, has no effect.
    public func cancel() {
        guard let identifier else { return }
        RouterRuntime.shared.cancel(identifier: identifier)
    }
}
