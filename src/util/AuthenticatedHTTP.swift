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

// HTTP client that manages OAuth2 tokens
class AuthenticatedHTTP {
    
    let oaClient: OAuth2Client
    
    var accessToken: String?
    var refreshToken: String?
    
    init(oaClient: OAuth2Client) {
        self.oaClient = oaClient
    }
    
    func executeOAuth2Request(request: OAuth2Request, callback: ACallback) {
        Alamofire.request(.POST, request.url, parameters: request.body).responseJSON(completionHandler: callback)
    }
    
    func executeOAuth2TokenRequest(request: OAuth2Request, callback: Bool -> ()) {
        executeOAuth2Request(request) { response in
            guard let data = response.result.value else {
                callback(false)
                return
            }
            
            let tokens = OAuth2Tokens(data)
            
            self.accessToken = tokens.accessToken ?? self.accessToken
            self.refreshToken = tokens.refreshToken ?? self.refreshToken
            
            callback(tokens.accessToken != nil)
        }
    }
    
    func createCodeAuthorizationUrl(scopes scopes: [String], extraQuery: [String: String] = [:]) -> NSURL? {
        return self.oaClient.createAuthorizationUrlFor(.AuthorizationCode, scopes: scopes, extraQuery: extraQuery)
    }
    
    func authenticateWithCode(code: String, callback: Bool -> ()) {
        let tokensRequest = self.oaClient.requestForTokensFromAuthorizationCode(code)
        executeOAuth2TokenRequest(tokensRequest, callback: callback)
    }
    
    func refreshTokens(callback: Bool -> ()) {
        guard let refreshToken = self.refreshToken else {
            callback(false)
            return
        }
        
        let tokensRequest = self.oaClient.requestForTokensFromRefreshToken(refreshToken)
        executeOAuth2TokenRequest(tokensRequest, callback: callback)
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
            self.refreshTokens() { gotNewTokens in
                if gotNewTokens {
                    self.unauthorizedRequestJSON(authorizedRequest, callback: callback)
                } else {
                    callback(response)
                }
            }
        }
        
    }
}
