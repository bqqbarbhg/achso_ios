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

enum AuthenticationResult {
    case OldSession
    case NewSession
    case Error(ErrorType)
    
    var isAuthenticated: Bool {
        switch self {
        case .OldSession: return true
        case .NewSession: return true
        case .Error: return false
        }
    }
    
    var error: ErrorType? {
        switch self {
        case .Error(let error): return error
        default: return nil
        }
    }
}

// HTTP client that manages OAuth2 tokens
class AuthenticatedHTTP {
    
    let oaClient: OAuth2Client
    
    var accessToken: String?
    var refreshToken: String?
    var tokenExpiryDate: NSDate?
    
    init(oaClient: OAuth2Client) {
        self.oaClient = oaClient
    }
    
    func executeOAuth2Request(request: OAuth2Request, callback: ACallback) {
        Alamofire.request(.POST, request.url, parameters: request.body).responseJSON(completionHandler: callback)
    }
    
    func executeOAuth2TokenRequest(request: OAuth2Request, createSession: Bool, callback: AuthenticationResult -> ()) {
        executeOAuth2Request(request) { response in
            guard let data = response.result.value else {
                callback(.Error(AssertionError("Response is JSON")))
                return
            }
            
            let tokens = OAuth2Tokens(data)
            
            self.accessToken = tokens.accessToken ?? self.accessToken
            self.refreshToken = tokens.refreshToken ?? self.refreshToken
            
            let expiryTimePadding = 5 // seconds
            self.tokenExpiryDate = tokens.expiresIn.map { expiresIn in
                NSDate(timeIntervalSinceNow: Double(expiresIn - expiryTimePadding))
            }
            
            if tokens.accessToken == nil {
                callback(.Error(UserError.failedToAuthenticate.withDebugError("No response token found")))
            } else {
                callback(createSession ? .NewSession : .OldSession)
            }
        }
    }
    
    func refreshIfNecessary(callback: AuthenticationResult -> ()) {
        // If the access token is still valid no need to refresh
        if self.accessToken != nil && (self.tokenExpiryDate.map({ $0 < NSDate() }) ?? false) {
            callback(.OldSession)
            return
        }
        
        self.refreshTokens(callback)
    }
    
    func createCodeAuthorizationUrl(scopes scopes: [String], extraQuery: [String: String] = [:]) -> NSURL? {
        return self.oaClient.createAuthorizationUrlFor(.AuthorizationCode, scopes: scopes, extraQuery: extraQuery)
    }
    
    func authenticateWithCode(code: String, callback: AuthenticationResult -> ()) {
        let tokensRequest = self.oaClient.requestForTokensFromAuthorizationCode(code)
        executeOAuth2TokenRequest(tokensRequest, createSession: true, callback: callback)
    }
    
    func refreshTokens(callback: AuthenticationResult -> ()) {
        guard let refreshToken = self.refreshToken else {
            callback(.Error(UserError.notSignedIn))
            return
        }
        
        let tokensRequest = self.oaClient.requestForTokensFromRefreshToken(refreshToken)
        executeOAuth2TokenRequest(tokensRequest, createSession: false, callback: callback)
    }
    
    func unauthorizedRequestJSON(request: HTTPRequest, callback: ACallback) {
        
        Alamofire.request(request.method, request.url, parameters: request.parameters, encoding: request.encoding, headers: request.headers)
            .responseJSON(completionHandler: callback)
        
    }
    
    func shouldRetryResponse(response: AResponse) -> Bool {
        guard let nsResponse = response.response else { return false }
        
        return [401, 403, 404, 500].contains(nsResponse.statusCode)
    }
    
    func authorizeRequest(request: HTTPRequest) -> HTTPRequest {
        var headers = request.headers ?? [:]
        
        if let bearerToken = self.accessToken {
            headers["Authorization"] = "Bearer \(bearerToken)"
        }
        
        return HTTPRequest(request.method, request.url, parameters: request.parameters, encoding: request.encoding, headers: headers)
    }
    
    func authorizedRequestJSON(request: HTTPRequest, canRetry: Bool, callback: ACallback) {
        
        let authorizedRequest = authorizeRequest(request)
        
        // Do the request directly if no need to retry
        if !canRetry {
            unauthorizedRequestJSON(authorizedRequest, callback: callback)
            return
        }
        
        unauthorizedRequestJSON(authorizedRequest) { response in
            
            // Call the callback directly if no need to retry
            if !self.shouldRetryResponse(response) {
                callback(response)
                return
            }
            
            // Refresh the tokens and retry if got new ones
            self.refreshTokens() { result in
                if result.isAuthenticated {
                    self.unauthorizedRequestJSON(authorizedRequest, callback: callback)
                } else {
                    callback(response)
                }
            }
        }
        
    }
}
