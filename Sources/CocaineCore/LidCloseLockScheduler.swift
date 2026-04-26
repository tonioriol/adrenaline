import Foundation

@MainActor
public protocol LidCloseLockCancellable: AnyObject {
    func cancel()
}

@MainActor
public protocol LidCloseLockScheduling: AnyObject {
    func schedule(after delay: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> LidCloseLockCancellable
}

@MainActor
public final class TaskLidCloseLockScheduler: LidCloseLockScheduling {
    public init() {}

    public func schedule(after delay: TimeInterval, operation: @escaping @MainActor @Sendable () -> Void) -> LidCloseLockCancellable {
        let clampedDelay = max(0, delay)
        let maxSeconds = Double(UInt64.max) / 1_000_000_000
        let nanoseconds = UInt64(min(clampedDelay, maxSeconds) * 1_000_000_000)

        let task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            operation()
        }

        return TaskLidCloseLockCancellable(task: task)
    }
}

@MainActor
private final class TaskLidCloseLockCancellable: LidCloseLockCancellable {
    private let task: Task<Void, Never>

    init(task: Task<Void, Never>) {
        self.task = task
    }

    deinit {
        task.cancel()
    }

    func cancel() {
        task.cancel()
    }
}
