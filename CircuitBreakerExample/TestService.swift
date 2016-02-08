import Foundation

public class TestService {
    
    public typealias CompletionBlock = (NSData?, ErrorType?) -> Void
    
    public func successCall(completion: CompletionBlock) {
        makeCall("get", completion: completion)
    }
    
    public func failureCall(completion: CompletionBlock) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            completion(nil, NSError(domain: "TestService", code: 404, userInfo: nil))
        }
    }
    
    public func delayedCall(delayInSeconds: Int, completion: CompletionBlock) {
        makeCall("delay/\(delayInSeconds)", completion: completion)
    }
    
    private func makeCall(path: String, completion: CompletionBlock) {
        let task = NSURLSession.sharedSession().dataTaskWithURL(NSURL(string: "https://httpbin.org/\(path)")!) { data, response, error in
            dispatch_async(dispatch_get_main_queue()) {
                completion(data, error)
            }
        }
        task.resume()
    }
    
}
