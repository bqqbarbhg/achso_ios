/*

`HTTPClient` manages some configuration things for services. It's not very good right now and is ripe for refactoring.

*/

import UIKit

class HTTPClient {
   
    static let callbackUrl: NSURL = NSURL(string: "app://achso.legroup.aalto.fi")!
    static var http: AuthenticatedHTTP?
    
    // Setup the OpenID Connect API
    static func setupOIDC(endPointUrl endpointUrl: NSURL, clientId: String, clientSecret: String) {
        
        let oaProvider = OAuth2Provider(baseUrl: endpointUrl, authorizePath: "authorize", tokenPath: "token")
        let oaClient = OAuth2Client(provider: oaProvider, clientId: clientId, clientSecret: clientSecret, callbackUrl: callbackUrl)
        
        self.http = AuthenticatedHTTP(oaClient: oaClient, userInfoEndpoint: endpointUrl.URLByAppendingPathComponent("userinfo"))
        
        if let user = AuthUser.user {
            if user.authorizeUrl != oaProvider.authorizeUrl {
                HTTPClient.signOut()
            }
        }
    }
    
    // Opens the LoginWebViewController and present the authentication page and creates a session if successful.
    static func authenticate(fromViewController viewController: UIViewController, callback userCallback: AuthenticationResult -> ()) {

        func callback(result: AuthenticationResult) {
            switch result {
            case .NewSession: setupApiWrappers()
            default: break
            }
            
            userCallback(result)
        }

        func loginRedirected(request: NSURLRequest) {
            
            guard let url = request.URL else { return }
            guard let code = OAuth2Client.parseCodeFromCallbackUrl(url) else { return }
            
            if let http = self.http {
                http.authenticateWithCode(code, callback: callback)
            }
        }
        
        guard let http = self.http else {
            callback(.Error(UserError.invalidLayersBoxUrl.withDebugError("HTTP client not initialized")))
            return
        }
        
        let scopes = ["openid", "profile", "email", "offline_access"]
        let query = ["prompt": "login", "display": "touch"]
        
        guard let authUrl = http.createCodeAuthorizationUrl(scopes: scopes, extraQuery: query) else {
            callback(.Error(UserError.invalidLayersBoxUrl.withDebugError("Could not create authorization URL")))
            return
        }
        
        let loginNav = viewController.storyboard!.instantiateViewControllerWithIdentifier("LoginWebViewController") as! UINavigationController
        let loginController = loginNav.topViewController as! LoginWebViewController
        loginController.prepareForLogin(url: authUrl, trapUrlPrefix: "app://", callback: loginRedirected)
        
        viewController.presentViewController(loginNav, animated: true, completion: nil)
    }
    
    // Validate and possibly refresh the user session and call `callback` with the status.
    static func doAuthenticated(callback: AuthenticationResult -> ()) {
        guard let http = self.http else {
            callback(.Error(UserError.invalidLayersBoxUrl.withDebugError("HTTP client not initialized")))
            return
        }
        
        http.refreshIfNecessary(callback)
    }
    
    // End the current session.
    static func signOut() {
        AuthUser.user = nil
        videoRepository.achRails = nil
        AppDelegate.instance.saveUserSession()
        videoRepository.refresh()
    }
    
    // Setup the API wrappers after authenticating.
    // TODO: Update this to work with the Layers Box.
    static func setupApiWrappers() {
        guard let http = HTTPClient.http else { return }
        guard let user = AuthUser.user else { return }
        
        if let achrailsUrl = Secrets.getUrl("ACHRAILS_URL") {
            let achrails = AchRails(http: http, endpoint: achrailsUrl, userId: user.id)
            videoRepository.achRails = achrails
        }
        
        if let achminupUrl = Secrets.getUrl("ACHMINUP_URL") {
            let achminup = AchMinUpUploader(endpoint: achminupUrl)
            videoRepository.videoUploaders = [achminup]
            videoRepository.thumbnailUploaders = [achminup]
        }
        
        AppDelegate.instance.saveUserSession()
        
        videoRepository.refreshOnline()
    }
}

