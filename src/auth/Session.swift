/*

Manages a connection to a Layers Box or a public set of servers. `Session` consists of the current authenticated HTTP client and possible user.

The session is stored in disk with `NSCoding` using `SessionData`.

*/

import Foundation
import Alamofire

class Session {

    static let callbackUrl: NSURL = NSURL(string: "app://achso.legroup.aalto.fi")!
    
    static private var layersBoxUrl: NSURL? = nil

    static private var isRetrievingTokens: Bool = false
    static private var http: AuthenticatedHTTP? = nil
    static private var pendingHttpClientRequests: [AuthenticatedHTTP? -> ()] = []
    
    static private var achrailsUrl: NSURL? = nil
    static private var achminupUrl: NSURL? = nil
    static private var govitraUrl: NSURL? = nil
    
    // Serialization
    static let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.URLByAppendingPathComponent("session")
    
    class SessionData: NSObject, NSCoding {
        
        let layersBoxUrl: NSURL?
        let oidcClientId: String?
        let oidcClientSecret: String?
        let user: AuthUser?
        
        init(layersBoxUrl: NSURL?, oidcClientId: String?, oidcClientSecret: String?, user: AuthUser?) {
            self.layersBoxUrl = layersBoxUrl
            self.oidcClientId = oidcClientId
            self.oidcClientSecret = oidcClientSecret
            self.user = user
        }
        
        required convenience init?(coder aCoder: NSCoder) {
            let layersBoxUrl = aCoder.decodeObjectForKey("layersBoxUrl") as? NSURL
            let oidcClientId = aCoder.decodeObjectForKey("oidcClientId") as? String
            let oidcClientSecret = aCoder.decodeObjectForKey("oidcClientSecret") as? String
            let user = aCoder.decodeObjectForKey("user") as? AuthUser
            
            self.init(layersBoxUrl: layersBoxUrl, oidcClientId: oidcClientId, oidcClientSecret: oidcClientSecret, user: user)
        }
        
        func encodeWithCoder(aCoder: NSCoder) {
            aCoder.encodeObject(self.layersBoxUrl, forKey: "layersBoxUrl")
            aCoder.encodeObject(self.oidcClientId, forKey: "oidcClientId")
            aCoder.encodeObject(self.oidcClientSecret, forKey: "oidcClientSecret")
            aCoder.encodeObject(self.user, forKey: "user")
        }
    }
    
    static var user: AuthUser? {
        return self.http?.authUser
    }
    
    static func reset() {
        self.achrailsUrl = nil
        self.achminupUrl = nil
        self.govitraUrl = nil
        
        videoRepository.achRails = nil
        videoRepository.videoUploaders = []
        
        http = nil
        for callback in pendingHttpClientRequests {
            callback(nil)
        }
        pendingHttpClientRequests.removeAll()
        videoRepository.refresh()
    }
    
    static func setupOIDC(endPointUrl endpointUrl: NSURL, clientId: String, clientSecret: String) {
        
        let oaProvider = OAuth2Provider(baseUrl: endpointUrl, authorizePath: "authorize", tokenPath: "token")
        let oaClient = OAuth2Client(provider: oaProvider, clientId: clientId, clientSecret: clientSecret, callbackUrl: callbackUrl)
        
        self.http = AuthenticatedHTTP(oaClient: oaClient, userInfoEndpoint: endpointUrl.URLByAppendingPathComponent("userinfo"))
        
        for callback in pendingHttpClientRequests {
            callback(self.http)
        }
        pendingHttpClientRequests.removeAll()
    }

    static func connectToPublicServers() {
        
        if self.http != nil && self.layersBoxUrl == nil {
            // Already set up to public
            return
        }
        
        self.reset()
        
        guard let
            endpointString: String = Secrets.get("LAYERS_OIDC_URL"),
            endpoint: NSURL = NSURL(string: endpointString),
            clientId: String = Secrets.get("LAYERS_OIDC_CLIENT_ID"),
            clientSecret: String = Secrets.get("LAYERS_OIDC_CLIENT_SECRET") else {
                
                return
        }
        
        self.achrailsUrl = Secrets.getUrl("ACHRAILS_URL")
        self.achminupUrl = Secrets.getUrl("ACHMINUP_URL")
        self.govitraUrl = nil
        
        self.layersBoxUrl = nil
        self.setupOIDC(endPointUrl: endpoint, clientId: clientId, clientSecret: clientSecret)
        
    }
    
    static func connectToPrivateLayersBox(url: NSURL) {
        
        if self.http != nil && self.layersBoxUrl == url {
            // Already set up to this private
            return
        }
        
        self.isRetrievingTokens = true
        self.reset()

        Alamofire.request(.GET, url.URLByAppendingPathComponent("/achrails/oidc_tokens"))
            .responseJSON { result in
                do {
                    let json = try (result.result.value as? JSONObject).unwrap()
                    let clientId: String = try json.castGet("client_id")
                    let clientSecret: String = try json.castGet("client_secret")
                    
                    self.doConnectToPrivateLayersBox(url, clientId: clientId, clientSecret: clientSecret)
                    
                    self.isRetrievingTokens = false
                    
                } catch {
                    self.reset()
                }
        }
    }
    
    static func checkOIDCTokens(callback: ErrorType? -> ()) {
        guard let url = self.layersBoxUrl else {
            return
        }
        
        Alamofire.request(.GET, url.URLByAppendingPathComponent("/achrails/oidc_tokens"))
            .responseJSON { result in
                do {
                    let json = try (result.result.value as? JSONObject).unwrap()
                    let clientId: String = try json.castGet("client_id")
                    let clientSecret: String = try json.castGet("client_secret")
                    let oaClient = try (self.http?.oaClient).unwrap()
                    
                    if clientId != oaClient.clientId || clientSecret != oaClient.clientSecret {
                        self.doConnectToPrivateLayersBox(url, clientId: clientId, clientSecret: clientSecret)
                        throw DebugError("OIDC client has changed")
                    }
                } catch {
                    callback(error)
                }
        }
        
    }
    
    static func doConnectToPrivateLayersBox(url: NSURL, clientId: String, clientSecret: String) {
        self.layersBoxUrl = url
        
        let oidcEndpoint = url.URLByAppendingPathComponent("/o/oauth2", isDirectory: true)
        self.achrailsUrl = url.URLByAppendingPathComponent("/achrails", isDirectory: true)
        self.achminupUrl = url.URLByAppendingPathComponent("/achminup", isDirectory: true)
        self.govitraUrl = url.URLByAppendingPathComponent("/govitra-api", isDirectory: true)
        self.setupOIDC(endPointUrl: oidcEndpoint, clientId: clientId, clientSecret: clientSecret)
    }
    
    static func setupApiWrappers() {
        guard let http = self.http, user = http.authUser else { return }
        
        if let achrailsUrl = self.achrailsUrl {
            let achrails = AchRails(http: http, endpoint: achrailsUrl, userId: user.id)
            videoRepository.achRails = achrails
        }
        
        var videoUploaders = [VideoUploader]()
        var thumbnailUploaders = [ThumbnailUploader]()
        
        
        if let govitraUrl = self.govitraUrl {
            let govitra = GoViTraUploader(endpoint: govitraUrl)
            videoUploaders.append(govitra)
        }
        
        if let achminupUrl = self.achminupUrl {
            let achminup = AchMinUpUploader(endpoint: achminupUrl)
            videoUploaders.append(achminup)
            thumbnailUploaders.append(achminup)
        }
        
        videoRepository.videoUploaders = videoUploaders
        videoRepository.thumbnailUploaders = thumbnailUploaders
    }
    
    static func withHttp(callback: AuthenticatedHTTP? -> ()) {
        if http == nil && isRetrievingTokens {
            pendingHttpClientRequests.append(callback)
        } else {
            callback(http)
        }
    }
    
    // Opens the LoginWebViewController and present the authentication page and creates a session if successful.
    static func authenticate(fromViewController viewController: UIViewController, callback userCallback: AuthenticationResult -> ()) {
        
        func callback(result: AuthenticationResult) {
            switch result {
            case .NewSession: setupApiWrappers()
            default: break
            }
            
            self.save()
            
            userCallback(result)
        }
        
        func loginRedirected(request: NSURLRequest) {
            
            guard let url = request.URL else { return }
            guard let code = OAuth2Client.parseCodeFromCallbackUrl(url) else { return }
            
            self.http?.authenticateWithCode(code, callback: callback)
        }
        
        self.withHttp() { maybeHttp in
        
            guard let http = maybeHttp else {
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
    }
    
    // Validate and possibly refresh the user session and call `callback` with the status.
    static func doAuthenticated(callback: AuthenticationResult -> ()) {
        self.withHttp() { maybeHttp in
            guard let http = maybeHttp else {
                callback(.Error(UserError.invalidLayersBoxUrl.withDebugError("HTTP client not initialized")))
                return
            }
            
            http.refreshIfNecessary(callback)
        }
    }
    
    static func signOut() {
        self.http?.authUser = nil
        videoRepository.achRails = nil
        videoRepository.videoUploaders = []
        Session.save()
        videoRepository.refresh()
    }
    
    static func save() {
        var oaClient = self.http?.oaClient

        // Don't store client id and secret for the public mode
        if self.layersBoxUrl == nil { oaClient = nil }
        
        let data = SessionData(layersBoxUrl: self.layersBoxUrl, oidcClientId: oaClient?.clientId, oidcClientSecret: oaClient?.clientSecret, user: self.http?.authUser)
        
        NSKeyedArchiver.archiveRootObject(data, toFile: self.ArchiveURL.path!)
    }
    
    static func load() {
        guard let data = NSKeyedUnarchiver.unarchiveObjectWithFile(self.ArchiveURL.path!) as? SessionData else {
            return
        }
        
        if data.layersBoxUrl == nil {
            self.connectToPublicServers()
        } else {
            if let url = data.layersBoxUrl, clientId = data.oidcClientId, clientSecret = data.oidcClientSecret {
                self.doConnectToPrivateLayersBox(url, clientId: clientId, clientSecret: clientSecret)
            }
        }
        
        if let http = self.http {
            http.authUser = data.user
            setupApiWrappers()
        }
    }
}
