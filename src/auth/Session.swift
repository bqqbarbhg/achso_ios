/*

Manages a connection to a Layers Box or a public set of servers. `Session` consists of the current authenticated HTTP client and possible user.

The session is stored in disk with `NSCoding` using `SessionData`.

*/

import Foundation
import Alamofire

class Session {

    static let callbackUrl: NSURL = NSURL(string: "app://achso.legroup.aalto.fi")!
    
    static private var layersBoxUrl: NSURL? = nil

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
        let user: AuthUser?
        
        init(layersBoxUrl: NSURL?, user: AuthUser?) {
            self.layersBoxUrl = layersBoxUrl
            self.user = user
        }
        
        required convenience init?(coder aCoder: NSCoder) {
            let layersBoxUrl = aCoder.decodeObjectForKey("layersBoxUrl") as? NSURL
            let user = aCoder.decodeObjectForKey("user") as? AuthUser
            
            self.init(layersBoxUrl: layersBoxUrl, user: user)
        }
        
        func encodeWithCoder(aCoder: NSCoder) {
            aCoder.encodeObject(self.layersBoxUrl, forKey: "layersBoxUrl")
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
    
    static func setupOIDC(endPointUrl endpointUrl: NSURL) {

        self.http = AuthenticatedHTTP(userInfoEndpoint: endpointUrl.URLByAppendingPathComponent("userinfo"))
        
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
        
        self.achrailsUrl = Secrets.getUrl("ACHRAILS_URL")
        //self.achminupUrl = Secrets.getUrl("ACHMINUP_URL")
        self.govitraUrl = Secrets.getUrl("GOVITRA_URL")
        
        self.layersBoxUrl = nil
        let _ = try? self.setupOIDC(endPointUrl: self.achrailsUrl.unwrap())
        
    }
    
    static func connectToPrivateLayersBox(url: NSURL) {
        
        if self.http != nil && self.layersBoxUrl == url {
            // Already set up to this private
            return
        }
        
        self.reset()
        self.doConnectToPrivateLayersBox(url)
    }
    
    static func doConnectToPrivateLayersBox(url: NSURL) {
        self.layersBoxUrl = url
        
        self.achrailsUrl = url.URLByAppendingPathComponent("/achrails", isDirectory: true)
        self.achminupUrl = url.URLByAppendingPathComponent("/achminup", isDirectory: true)
        self.govitraUrl = url.URLByAppendingPathComponent("/govitra-api", isDirectory: true)

        let _ = try? self.setupOIDC(endPointUrl: self.achrailsUrl.unwrap())
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
        if http == nil {
            pendingHttpClientRequests.append(callback)
        } else {
            callback(http)
        }
    }
    
    // Opens the SharesViewController and present the authentication page and creates a session if successful.
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
            
            func parseSessionTokenFromUrl(url: NSURL) -> String? {
                let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
                return components?.queryItems?.find { $0.name == "session" }?.value
            }
            
            guard let url = request.URL else {
                callback(.Error(DebugError("Redirected URL is not an URL")))
                return
            }
            guard let sessionToken = parseSessionTokenFromUrl(url) else {
                callback(.Error(DebugError("Failed to parse session token")))
                return
            }
            
            self.http?.getUserInfo(sessionToken, callback: callback)
        }
        
        self.withHttp() { _ in

            guard let achrailsUrl = self.achrailsUrl else {
                callback(.Error(UserError.invalidLayersBoxUrl.withDebugError("No achrails url")))
                return
            }
            
            let loginNav = viewController.storyboard!.instantiateViewControllerWithIdentifier("SharesViewController") as! UINavigationController
            let loginController = loginNav.topViewController as! SharesViewController
            
            do {
                try loginController.prepareForLogin(baseUrl: achrailsUrl, callback: loginRedirected)
            } catch {
                callback(.Error(error))
                return
            }
            
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
            
            callback(.OldSession(http))
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
        let data = SessionData(layersBoxUrl: self.layersBoxUrl, user: self.http?.authUser)
        
        NSKeyedArchiver.archiveRootObject(data, toFile: self.ArchiveURL.path!)
    }
    
    static func load() {
        guard let data = NSKeyedUnarchiver.unarchiveObjectWithFile(self.ArchiveURL.path!) as? SessionData else {
            return
        }
        
        if data.layersBoxUrl == nil {
            self.connectToPublicServers()
        } else {
            if let url = data.layersBoxUrl {
                self.doConnectToPrivateLayersBox(url)
            }
        }
        
        if let http = self.http {
            http.authUser = data.user
            setupApiWrappers()
        }
    }
}
