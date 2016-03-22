// MIT License: https://opensource.org/licenses/MIT
// Author: https://github.com/fe9lix/CircuitBreaker

import Foundation

public class CircuitBreaker {
    
    public enum State {
        case Closed
        case Open
        case HalfOpen
    }
    
    public let timeout: NSTimeInterval
    public let maxRetries: Int
    public let timeBetweenRetries: NSTimeInterval
    public let exponentialBackoff: Bool
    public let resetTimeout: NSTimeInterval
    public var call: (CircuitBreaker -> Void)?
    public var didTrip: ((CircuitBreaker, ErrorType?) -> Void)?
    public private(set) var failureCount = 0
    
    public var state: State {
        if let lastFailureTime = lastFailureTime
            where (failureCount > maxRetries) &&
                (NSDate().timeIntervalSince1970 - lastFailureTime) > resetTimeout {
                    return .HalfOpen
        }
        
        if failureCount > maxRetries {
            return .Open
        }
        
        return .Closed
    }
    
    private var lastError: ErrorType?
    private var lastFailureTime: NSTimeInterval?
    private var timer: NSTimer?
    
    public init(
        timeout: NSTimeInterval = 10,
        maxRetries: Int = 2,
        timeBetweenRetries: NSTimeInterval = 2,
        exponentialBackoff: Bool = true,
        resetTimeout: NSTimeInterval = 10) {
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.timeBetweenRetries = timeBetweenRetries
            self.exponentialBackoff = exponentialBackoff
            self.resetTimeout = resetTimeout
    }
    
    // MARK: - Public API
    
    public func execute() {
        timer?.invalidate()
        
        switch state {
        case .Closed, .HalfOpen:
            doCall()
        case .Open:
            trip()
        }
    }
    
    public func success() {
        reset()
    }
    
    public func failure(error: ErrorType? = nil) {
        timer?.invalidate()
        lastError = error
        lastFailureTime = NSDate().timeIntervalSince1970
        failureCount += 1
        
        switch state {
        case .Closed, .HalfOpen:
            retryAfterDelay()
        case .Open:
            trip()
        }
    }
    
    public func reset() {
        timer?.invalidate()
        failureCount = 0
        lastFailureTime = nil
        lastError = nil
    }
    
    // MARK: - Call & Timeout
    
    private func doCall() {
        call?(self)
        startTimer(timeout, selector: #selector(didTimeout(_:)))
    }
    
    @objc private func didTimeout(timer: NSTimer) {
        failure()
    }
    
    // MARK: - Retry
    
    private func retryAfterDelay() {
        let delay = exponentialBackoff ? pow(timeBetweenRetries, Double(failureCount)) : timeBetweenRetries
        startTimer(delay, selector: #selector(shouldRetry(_:)))
    }
    
    @objc private func shouldRetry(timer: NSTimer) {
        doCall()
    }
    
    // MARK: - Trip
    
    private func trip() {
        didTrip?(self, lastError)
    }
    
    // MARK: - Timer
    
    private func startTimer(delay: NSTimeInterval, selector: Selector) {
        timer?.invalidate()
        timer = NSTimer.scheduledTimerWithTimeInterval(
            delay,
            target: self,
            selector: selector,
            userInfo: nil,
            repeats: false
        )
    }
    
}
