import XCTest
@testable import CircuitBreaker

class CircuitBreakerTests: XCTestCase {
    
    private var testService: TestService!
    private var circuitBreaker: CircuitBreaker!
    
    override func setUp() {
        super.setUp()
        
        testService = TestService()
    }
    
    override func tearDown() {
        circuitBreaker.reset()
        circuitBreaker.didTrip = nil
        circuitBreaker.call = nil
        
        super.tearDown()
    }
    
    func testSuccess() {
        let expectation = expectationWithDescription("Successful call")
        
        circuitBreaker = CircuitBreaker()
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.successCall { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                circuitBreaker.success()
                expectation.fulfill()
            }
        }
        circuitBreaker.execute()
        
        waitForExpectationsWithTimeout(10) { _ in }
    }
    
    func testTimeout() {
        let expectation = expectationWithDescription("Timed out call")
        
        circuitBreaker = CircuitBreaker(timeout: 3.0)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.delayedCall(5) { _ in }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    expectation.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectationsWithTimeout(15) { _ in }
    }
    
    func testFailure() {
        let expectation = expectationWithDescription("Failure call")
        
        circuitBreaker = CircuitBreaker(timeout: 10.0, maxRetries: 1)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.failureCall { data, error in
                    XCTAssertNil(data)
                    XCTAssertNotNil(error)
                    circuitBreaker.failure()
                }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    expectation.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectationsWithTimeout(10) { _ in }
    }
    
    func testTripping() {
        let expectation = expectationWithDescription("Tripped call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 2,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        
        circuitBreaker.didTrip = { circuitBreaker, error in
            XCTAssertTrue(circuitBreaker.state == .Open)
            XCTAssertTrue(circuitBreaker.failureCount == circuitBreaker.maxRetries + 1)
            XCTAssertTrue((error as! NSError).code == 404)
            circuitBreaker.reset()
            expectation.fulfill()
        }
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.failureCall { data, error in
                circuitBreaker.failure(NSError(domain: "TestService", code: 404, userInfo: nil))
            }
        }
        circuitBreaker.execute()
        
        waitForExpectationsWithTimeout(100) { error in
            print(error)
        }
    }
    
    func testReset() {
        let expectation = expectationWithDescription("Reset call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 1,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        circuitBreaker.call = { [weak self] circuitBreaker in
            if circuitBreaker.state == .HalfOpen {
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    XCTAssertTrue(circuitBreaker.state == .Closed)
                    expectation.fulfill()
                }
                return
            }
            
            self?.testService.failureCall { data, error in
                circuitBreaker.failure()
            }
        }
        circuitBreaker.execute()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(4.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.circuitBreaker.execute()
        }
        
        waitForExpectationsWithTimeout(10) { _ in }
    }
    
}


