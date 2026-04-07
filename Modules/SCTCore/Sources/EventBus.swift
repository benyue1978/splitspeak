import Foundation

public actor EventBus {
    private var continuations: [UUID: AsyncStream<SCTEvent>.Continuation] = [:]
    
    public init() {}
    
    /// Subscribe to the event bus.
    /// - Parameter bufferingPolicy: The buffering policy for the stream. Defaults to `.unbounded`.
    /// - Returns: An AsyncStream of SCTEvents.
    public func subscribe(bufferingPolicy: AsyncStream<SCTEvent>.Continuation.BufferingPolicy = .unbounded) -> AsyncStream<SCTEvent> {
        let id = UUID()
        var continuation: AsyncStream<SCTEvent>.Continuation!
        let stream = AsyncStream(SCTEvent.self, bufferingPolicy: bufferingPolicy) { continuation = $0 }
        
        self.continuations[id] = continuation
        
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { [weak self] in
                await self?.removeContinuation(id: id)
            }
        }
        
        return stream
    }
    
    /// Publish an event to all active subscribers.
    /// - Parameter event: The event to publish.
    public func publish(_ event: SCTEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
    
    /// Internal method to check the number of active subscribers (useful for testing).
    func subscriptionCount() -> Int {
        return continuations.count
    }
    
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
