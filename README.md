[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](http://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/swift-2.0-orange.svg)](https://developer.apple.com/swift/blog/?id=29)

# CircuitBreaker

Implementation of the [Circuit Breaker](http://martinfowler.com/bliki/CircuitBreaker.html) design pattern in Swift. Circuit Breakers are most useful for networking where remote calls can fail or time out at any moment. When configured thresholds are reached, the circuit breaker "trips" and thus prevents putting unnecessary load on the server until the breaker resets itself after a timeout. In addition, this implementation provides convenience features such as monitoring call timeouts and supporting retry logic with exponential backoff.

## Requirements

*>=* iOS 8, Xcode 7, Swift 2.0

## Installation
You can either use [Carthage](https://github.com/Carthage/Carthage) and then import the framework or simply copy the file `CircuitBreaker.swift` to your project.

## Usage

```swift
let circuitBreaker = CircuitBreaker(
  timeout: 10.0,
  maxRetries: 2,
  timeBetweenRetries: 2.0,
  exponentialBackoff: true,
  resetTimeout: 2.0 
)

circuitBreaker.call = { [weak self] circuitBreaker in
  self?.someRemoteService.call { data, error in
    if let error = error {
      circuitBreaker.failure(error)
    } else {
      circuitBreaker.success()
    }
  }
}

circuitBreaker.didTrip = { circuitBreaker, error in 
  print("didTrip", error)
}

circuitBreaker.execute()
```

After initializing a `CircuitBreaker` instance, a closure is registered that is executed when the `execute` method is called or when the call is automatically retried after recording an error with the `failure` method. When the threshold is reached after `maxRetries`, the actual call is *not* performed but instead the `didTrip` closure is triggered. The breaker is now in the `Open` state. When `resetTimeout` has passed, the breaker is in the `HalfOpen` state. Another call to `execute` now sets the breaker back to `Closed` as soon as the `success` method is called.  

### Configuration
`CircuitBreaker`can be configured with five parameters:

- `timeout`: Timeout in seconds (per call). When no failure or success was recorded within timeout, the call is automatically retried. 
- `maxRetries`: The maximum number of retries before the breaker trips.
- `timeBetweenRetries`: Time in seconds between retries. Used as base when `exponentialBackoff` is true.
- `exponentialBackoff`: Increases the time between retries (when `timeBetweenRetries > 1.0`) exponentially when set to `true`.
- `resetTimeout`: Time in seconds after which the breaker is reset when it was "tripped".

### Public Interface
The main public interface consists of four methods and two properties for registering closures:

- `execute()`: Executes the closure registered via the `call` property.
- `success()`: Records a successful call and resets the circuit breaker. Call this method when your (asynchronous) method call was successful. 
- `failure(error: ErrorType? = nil)`: Records a failure with an optional error conforming to `ErrorType`. Executing this method may trigger the `call` closure again for retrying or it may trip the breaker by triggering the closure registered via `didTrip`. `didTrip` also receives the last error provided by `failure()` as second parameter.
- `reset()`: Stops all timeouts and resets the breaker to the default state. Note: Call this method when you need to cancel your call and deallocate the circuit breaker.

Additionally, two read-only properties expose the state of the circuit breaker:
- `state`: Returns one of `.Closed`, `.HalfOpen` or `Open`.  
- `failureCount`: Returns the current count of failure calls. 

## Example
See the main `ViewController.swift` for a basic example that performs calls against a test service and logs the circuit breaker state.

## Tests
See `CircuitBreakerTests.swift` for a couple of unit tests.

## Author

fe9lix

## License

CircuitBreaker is available under the MIT license. See the LICENSE file for more info.
