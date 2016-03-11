/*

`AuthenticatedHTTP` is a HTTP client that can make requests using OAuth2 Bearer authentication. It retrieves the authentication tokens and tries to refresh them if they have expired.

Uses OAuth2.swift internally.

*/

import Alamofire

enum AuthenticationResult {
    case OldSession(AuthenticatedHTTP)
    case NewSession(AuthenticatedHTTP)
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
    
    var http: AuthenticatedHTTP? {
        switch self {
        case .OldSession(let http): return http
        case .NewSession(let http): return http
        default: return nil
        }
    }
}


// HTTP client that manages OAuth2 tokens
class AuthenticatedHTTP {
    
    let userInfoEndpoint: NSURL
    
    var authUser: AuthUser?
    
    init(userInfoEndpoint: NSURL) {
        self.userInfoEndpoint = userInfoEndpoint
    }
    
    func getUserInfo(session: String, callback: AuthenticationResult -> ()) {
        
        let request = self.userInfoEndpoint.request(.GET)
        self.authorizedRequestJSON(request, session: session) { response in
            do {
                let responseJson = try (response.result.value as? JSONObject).unwrap()
                let sub: String = try responseJson.castGet("sub")
                let name: String = try responseJson.castGet("name")
                
                self.authUser = AuthUser(session: session, id: sub, name: name, authorizeUrl: self.userInfoEndpoint)
                
                callback(.NewSession(self))
            } catch {
                callback(.Error(error))
            }
        }
    }
    
    
    func unauthorizedRequestJSON(request: HTTPRequest, callback: ACallback) {
        
        Alamofire.request(request.method, request.url, parameters: request.parameters, encoding: request.encoding, headers: request.headers)
            .responseJSON(completionHandler: callback)
        
    }
    
    func authorizeRequest(request: HTTPRequest, session: String?) -> HTTPRequest {
        var headers = request.headers ?? [:]
        
        if let session = session {
            headers["Authorization"] = "Bearer \(session)"
        }
        
        return HTTPRequest(request.method, request.url, parameters: request.parameters, encoding: request.encoding, headers: headers)
    }
    
    func authorizeRequest(request: HTTPRequest) -> HTTPRequest {
        return authorizeRequest(request, session: self.authUser?.session)
    }
    
    func shouldRetryResponse(response: AResponse) -> Bool {
        guard let nsResponse = response.response else { return false }
        
        return [401, 403, 404, 500].contains(nsResponse.statusCode)
    }
    
    func authorizedRequestJSON(request: HTTPRequest, session: String?, callback: ACallback) {
        
        let authorizedRequest = authorizeRequest(request, session: session)
        unauthorizedRequestJSON(authorizedRequest, callback: callback)
    }
    
    func authorizedRequestJSON(request: HTTPRequest, callback: ACallback) {
        self.authorizedRequestJSON(request, session: self.authUser?.session, callback: callback)
    }
}
