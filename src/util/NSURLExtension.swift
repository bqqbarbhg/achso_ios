import Alamofire

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
    
    // Create the directories described by this URL if it does not exist
    func createDirectoryIfUnexisting(attributes: [String: String]? = nil) throws -> NSURL {
        let fileManager = NSFileManager.defaultManager()
        if let path = self.path {
            if !fileManager.fileExistsAtPath(path) {
                try fileManager.createDirectoryAtURL(self, withIntermediateDirectories: true, attributes: attributes)
            }
        }
        return self
    }
    
    // Get the size of the resource described a this URL if possible
    func sizeInBytes() -> Int64? {
        let fileManager = NSFileManager.defaultManager()
        guard let path = self.path else { return nil }
        return (try? fileManager.attributesOfItemAtPath(path)[NSFileSize])??.longLongValue
    }
    
    // Resolve this URL, handles virtual iosdocuments:// type URLs
    var realUrl: NSURL? {
        if self.scheme != "iosdocuments" { return self }
        guard let path = self.path else { return nil }
        
        let fileManager = NSFileManager.defaultManager()
        let documents = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[safe: 0]
        return documents?.URLByAppendingPathComponent(path)
    }
    
    // Returns if the URL is local (file:// or iosdocuments://)
    var isLocal: Bool {
        return self.scheme == "file" || self.scheme == "iosdocuments"
    }
}

