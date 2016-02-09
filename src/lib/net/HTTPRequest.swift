/*

`HTTPRequest` is an object that specifies an HTTP request. This does not directly do any request but can be executed by some HTTP client supporting this basic structure.

This file also defines extension methods for creating requests from `NSURL`s.

    let request = url.request(.GET, "/relative")
    client.execute(request)

*/

import Alamofire

struct HTTPRequest {
    let method: Method
    let url: URLStringConvertible
    let parameters: [String: AnyObject]?
    let encoding: ParameterEncoding
    let headers: [String: String]?
    
    init(_ method: Method, _ url: URLStringConvertible, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL, headers: [String: String]? = nil) {
        self.method = method
        self.url = url
        self.parameters = parameters
        self.encoding = encoding
        self.headers = headers
    }
    
    init(_ method: Method, _ url: URLStringConvertible, json: [String: AnyObject], headers: [String: String]? = nil) {
        self.init(method, url, parameters: json, encoding: .JSON, headers: headers)
    }
}

extension NSURL {
    // Create a HTTP request instance. NOTE: does not actually execute the request
    func request(method: Method, _ path: String, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL, headers: [String: String]? = nil) -> HTTPRequest {
        let url = self.URLByAppendingPathComponent(path)
        return HTTPRequest(method, url, parameters: parameters, encoding: encoding, headers: headers)
    }
    
    // Create a HTTP request instance. NOTE: does not actually execute the request
    func request(method: Method, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL, headers: [String: String]? = nil) -> HTTPRequest {
        return HTTPRequest(method, self, parameters: parameters, encoding: encoding, headers: headers)
    }
    
    // Create a HTTP request instance. NOTE: does not actually execute the request
    func request(method: Method, _ path: String, json: [String: AnyObject], headers: [String: String]? = nil) -> HTTPRequest {
        return request(method, path, parameters: json, encoding: .JSON, headers: headers)
    }
    
    // Create a HTTP request instance. NOTE: does not actually execute the request
    func request(method: Method, json: [String: AnyObject], headers: [String: String]? = nil) -> HTTPRequest {
        return request(method, parameters: json, encoding: .JSON, headers: headers)
    }
}
