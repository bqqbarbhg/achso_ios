import Foundation

// A simple OAuth2 utility for creating API calls.
// NOTE: This does not actually do any HTTP requests! Use an external client for that.

/*

Initialization:

    let provider = OAuth2Provider(authorizeUrl: ..., tokenUrl: ...)
    let client = OAuth2Client(provider: provider, clientId: ..., clientSecret: ..., callbackUrl: ...)

Auhtorization flow:

    let authUrl = client.createAuthorizationUrlFor(.AuthorizationCode, scopes: [...])

    let redirectedUrl: NSURL = `openUrlInWebViewOrBrowserAndLookForRedirect`(authUrl)
    let code = OAuth2Client.parseCodeFromCallbackUrl(redirectedUrl)

    let tokensRequest = client.requestForTokensFromAuthorizationCode(code)
    let responseJson = `executePostRequest`(tokensRequest.url, tokensRequest.body)

    let tokens = OAuth2Tokens(responseJson)

Refreshing tokens:

    let oldTokens: OAuth2Tokens

    let refreshRequest = client.requestForTokensFromRefreshToken(oldTokens.refreshToken!)
    let responseJson = `executePostRequest`(refreshRequest.url, refreshRequest.body)

    let newTokens = OAuth2Tokens(responseJson)

*/

// An OAuth2 API descriptor
class OAuth2Provider {
    
    let authorizeUrl: NSURL
    let tokenUrl: NSURL
    
    // Initialize with the API endpoints
    init(authorizeUrl: NSURL, tokenUrl: NSURL) {
        self.authorizeUrl = authorizeUrl
        self.tokenUrl = tokenUrl
    }
    
    // Initialize with the API root and relative endpoints
    convenience init(baseUrl: NSURL, authorizePath: String, tokenPath: String) {
        self.init(authorizeUrl: baseUrl.URLByAppendingPathComponent(authorizePath),
            tokenUrl: baseUrl.URLByAppendingPathComponent(tokenPath))
    }
    
}

// POST request to `url` with an url-encoded `body`
typealias OAuth2Request = (url: NSURL, body: [String: AnyObject])

// Simple container for tokens returned by the token endpoint
struct OAuth2Tokens {

    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?

    // Parse tokens from a response JSON
    init(_ data: AnyObject) {
        guard let json = data as? [String: AnyObject] else {
            self.accessToken = nil
            self.refreshToken = nil
            self.expiresIn = nil
            self.tokenType = nil
            return
        }
        
        self.accessToken = json["access_token"] as? String
        self.refreshToken = json["refresh_token"] as? String
        self.expiresIn = json["expires_in"] as? Int
        self.tokenType = json["token_type"] as? String
    }
}

// A registered OAuth2 client that can be used create API calls.
class OAuth2Client {
    
    let provider: OAuth2Provider
    let clientId: String
    let clientSecret: String
    let callbackUrl: NSURL
    
    // Initialize with a provider and the registered values
    init(provider: OAuth2Provider, clientId: String, clientSecret: String, callbackUrl: NSURL) {
        self.provider = provider
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
    }

    // An authorization flow type.
    enum ResponseType {
        case AuthorizationCode
        case Custom(String)
        
        var queryParameterValue: String {
            switch self {
            case .AuthorizationCode: return "code"
            case .Custom(let str): return str
            }
        }
    }
    
    // Returns an URL to authorize the user. Do a GET request to the page with an HTML web client or open the URL in the native browser to authenticate.
    // scopes: OAuth2 scopes to authroize for
    // responseType: Which authorization flow to use
    // extraQuery: Custom query parameters appended to the URL for customizing the login page.
    func createAuthorizationUrlFor(responseType: ResponseType, scopes: [String], extraQuery: [String: String] = [:]) -> NSURL? {
        guard let components = NSURLComponents(URL: self.provider.authorizeUrl, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let queryParameters: [String: String] = [
            "client_id": self.clientId,
            "client_secret": self.clientSecret,
            "response_type": responseType.queryParameterValue,
            "scope": scopes.joinWithSeparator(","),
            "redirect_uri": self.callbackUrl.absoluteString,
        ]
        
        func dictToNSURLQueryItems(queryDict: [String: String]) -> [NSURLQueryItem] {
            return queryDict.map { (key, value) in NSURLQueryItem(name: key, value: value) }
        }
        
        let oldQueryItems = components.queryItems ?? []
        let newQueryItems = dictToNSURLQueryItems(queryParameters) + dictToNSURLQueryItems(extraQuery)
        
        components.queryItems = oldQueryItems + newQueryItems
        
        return components.URL
    }
    
    // Parse the code from an URL code flow auhtorization callback URL.
    // url: An URL that `createAuthorizationUrlFor(.AuthorizationCode, ...)` redirected the client to.
    static func parseCodeFromCallbackUrl(url: NSURL) -> String? {
        guard let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) else { return nil }
        let queryItems = components.queryItems ?? []
        
        for item in queryItems {
            if item.name == "code" {
                if let value = item.value {
                    return value
                }
            }
        }
        
        return nil
    }
    
    // Returns a POST request that will return the tokens from an authorization code.
    // code: Returned from `parseCodeFromCallbackUrl`.
    func requestForTokensFromAuthorizationCode(code: String) -> OAuth2Request {
        let body: [String: String] = [
            "client_id": self.clientId,
            "client_secret": self.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": self.callbackUrl.absoluteString,
        ]

        return OAuth2Request(url: provider.tokenUrl, body: body)
    }
    
    // Returns a POST request that will return a new set of tokens using a previously returned refresh token.
    func requestForTokensFromRefreshToken(refreshToken: String) -> OAuth2Request {
        let body: [String: String] = [
            "client_id": self.clientId,
            "client_secret": self.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "redirect_uri": self.callbackUrl.absoluteString,
        ]
        
        return OAuth2Request(url: provider.tokenUrl, body: body)
    }
}
