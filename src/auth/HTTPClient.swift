import UIKit

class HTTPClient {
   
    static let callbackUrl: NSURL = NSURL(string: "app://achso.legroup.aalto.fi")!
    static var http: AuthenticatedHTTP?
    
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
    
    static func authenticate(fromViewController viewController: UIViewController, callback userCallback: AuthenticationResult -> ()) {

        func callback(result: AuthenticationResult) {
            switch result {
            case .OldSession:
                userCallback(result)
                
            case .NewSession:
                // Delegate to get user info (name and id)
                tempSetup()
                userCallback(result)
                
            case .Error(let error):
                // TODO: Something
                userCallback(result)
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
        loginController.prepareForLogin(url: authUrl, trapUrlPrefix: "app://", callback: self.loginRedirected(callback: callback))
        
        viewController.presentViewController(loginNav, animated: true, completion: nil)
    }
    
    static func doAuthenticated(callback: AuthenticationResult -> ()) {
        guard let http = self.http else {
            callback(.Error(UserError.invalidLayersBoxUrl.withDebugError("HTTP client not initialized")))
            return
        }
        
        http.refreshIfNecessary(callback)
    }
    
    static func loginRedirected(callback callback: AuthenticationResult -> ())(request: NSURLRequest) {
        
        guard let url = request.URL else { return }
        guard let code = OAuth2Client.parseCodeFromCallbackUrl(url) else { return }
        
        if let http = self.http {
            http.authenticateWithCode(code, callback: callback)
        }
    }
    
    static func signOut() {
        AuthUser.user = nil
        videoRepository.achRails = nil
        AppDelegate.instance.saveUserSession()
        videoRepository.refresh()
    }
    
    static func tempSetup() {
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

