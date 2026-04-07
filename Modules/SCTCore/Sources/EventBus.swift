import Foundation

public actor EventBus {
    private var continuations: [UUID: AsyncStream<SCTEvent>.Continuation] = [:]
    
    public init() {}
    
    public func subscribe() -> AsyncStream<SCTEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            self.continuations[id] = continuation
            
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }
    
    public func publish(_ event: SCTEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
    
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
