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

typealias TokenSet = (access: String, expires: NSDate, refresh: String?)

// HTTP client that manages OAuth2 tokens
class AuthenticatedHTTP {
    
    let oaClient: OAuth2Client
    let userInfoEndpoint: NSURL
    
    var tokens: TokenSet? {
        return AuthUser.user?.tokens
    }
    
    init(oaClient: OAuth2Client, userInfoEndpoint: NSURL) {
        self.oaClient = oaClient
        self.userInfoEndpoint = userInfoEndpoint
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
            
            let expiryTimePadding = 5 // seconds
            
            let accessToken = tokens.accessToken
            let refreshToken = tokens.refreshToken ?? self.tokens?.refresh
            let expiresIn = tokens.expiresIn.map { expiresIn in
                NSDate(timeIntervalSinceNow: Double(expiresIn - expiryTimePadding))
            }
            
            if let newAccess = accessToken, newExpires = expiresIn {
                
                let tokens = TokenSet(access: newAccess, expires: newExpires, refresh: refreshToken)
                self.getUserInfo(tokens, callback: callback)
            } else {
                callback(.Error(UserError.failedToAuthenticate.withDebugError("No response token found")))
            }
        }
    }
    
    func getUserInfo(tokens: TokenSet, callback: AuthenticationResult -> ()) {
        
        let request = self.userInfoEndpoint.request(.GET)
        self.authorizedRequestJSON(request, canRetry: false, tokens: tokens) { response in
            do {
                let responseJson = try (response.result.value as? JSONObject).unwrap()
                let sub: String = try responseJson.castGet("sub")
                let name: String = try responseJson.castGet("name")
                
                let authorizeUrl = self.oaClient.provider.authorizeUrl
                AuthUser.user = AuthUser(tokens: tokens, id: sub, name: name, authorizeUrl: authorizeUrl)
                
                callback(.NewSession)
            } catch {
                callback(.Error(error))
            }
        }
    }
    
    func refreshIfNecessary(callback: AuthenticationResult -> ()) {
        // If the access token is still valid no need to refresh
        let isValid = (self.tokens?.expires).map({ $0 < NSDate() }) ?? false
        if self.tokens?.access != nil && isValid {
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
        guard let refreshToken = self.tokens?.refresh else {
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
    
    func authorizeRequest(request: HTTPRequest, tokens: TokenSet?) -> HTTPRequest {
        var headers = request.headers ?? [:]
        
        if let tokens = tokens {
            headers["Authorization"] = "Bearer \(tokens.access)"
        }
            
        return HTTPRequest(request.method, request.url, parameters: request.parameters, encoding: request.encoding, headers: headers)
    }
    
    func authorizedRequestJSON(request: HTTPRequest, canRetry: Bool, tokens: TokenSet?, callback: ACallback) {
        
        let authorizedRequest = authorizeRequest(request, tokens: tokens)
        
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
                self.authorizedRequestJSON(request, canRetry: false, callback: callback)
            }
        }
    }
    
    func authorizedRequestJSON(request: HTTPRequest, canRetry: Bool, callback: ACallback) {
        self.authorizedRequestJSON(request, canRetry: canRetry, tokens: self.tokens, callback: callback)
    }
}
