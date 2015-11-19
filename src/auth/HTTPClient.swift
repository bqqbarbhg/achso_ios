import UIKit

class HTTPClient {
   
    static let callbackUrl: NSURL = NSURL(string: "app://achso.legroup.aalto.fi")!
    static var http: AuthenticatedHTTP?
    
    static func setupOIDC(endPointUrl endpointUrl: NSURL, clientId: String, clientSecret: String) {
        
        let oaProvider = OAuth2Provider(baseUrl: endpointUrl, authorizePath: "authorize", tokenPath: "token")
        let oaClient = OAuth2Client(provider: oaProvider, clientId: clientId, clientSecret: clientSecret, callbackUrl: callbackUrl)
        
        self.http = AuthenticatedHTTP(oaClient: oaClient)
    }
    
    static func authenticate(fromViewController viewController: UIViewController) -> Bool {

        guard let http = self.http else { return false }
        
        let scopes = ["openid", "profile", "email", "offline_access"]
        let query = ["prompt": "login", "display": "touch"]
        
        guard let authUrl = http.createCodeAuthorizationUrl(scopes: scopes, extraQuery: query) else {
            return false
        }
        
        let loginController = viewController.storyboard!.instantiateViewControllerWithIdentifier("LoginWebViewController") as! LoginWebViewController
        loginController.prepareForLogin(url: authUrl, trapUrlPrefix: "app://", callback: self.loginRedirected)
        
        viewController.presentViewController(loginController, animated: true, completion: nil)
        return true
    }
    
    static func loginRedirected(request: NSURLRequest) {
        
        guard let url = request.URL else { return }
        guard let code = OAuth2Client.parseCodeFromCallbackUrl(url) else { return }
        
        if let http = self.http {
            http.authenticateWithCode(code, callback: self.httpAuthenticated)
        }
    }
    
    static func httpAuthenticated(wasSuccessful: Bool) {
        
        // TODO: Let everyone know
        
    }
    
}

