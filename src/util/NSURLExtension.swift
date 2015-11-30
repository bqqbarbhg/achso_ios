import Alamofire

extension NSURL {
    
    func request(method: Method, _ path: String, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL, headers: [String: String]? = nil) -> HTTPRequest {
        let url = self.URLByAppendingPathComponent(path)
        return HTTPRequest(method, url, parameters: parameters, encoding: encoding, headers: headers)
    }

    func request(method: Method, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL, headers: [String: String]? = nil) -> HTTPRequest {
        return HTTPRequest(method, self, parameters: parameters, encoding: encoding, headers: headers)
    }
    
    func request(method: Method, _ path: String, json: [String: AnyObject], headers: [String: String]? = nil) -> HTTPRequest {
        return request(method, path, parameters: json, encoding: .JSON, headers: headers)
    }
    
    func request(method: Method, json: [String: AnyObject], headers: [String: String]? = nil) -> HTTPRequest {
        return request(method, parameters: json, encoding: .JSON, headers: headers)
    }
    
    func createDirectoryIfUnexisting(attributes: [String: String]? = nil) throws -> NSURL {
        let fileManager = NSFileManager.defaultManager()
        if let path = self.path {
            if !fileManager.fileExistsAtPath(path) {
                try fileManager.createDirectoryAtURL(self, withIntermediateDirectories: true, attributes: attributes)
            }
        }
        return self
    }
    
    func sizeInBytes() -> Int64? {
        let fileManager = NSFileManager.defaultManager()
        guard let path = self.path else { return nil }
        return (try? fileManager.attributesOfItemAtPath(path)[NSFileSize])??.longLongValue
    }
}

