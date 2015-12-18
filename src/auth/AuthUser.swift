import Foundation

// Represents an authenticated OIDC user.
class AuthUser: NSObject, NSCoding {

    // The currently authenticated user (if exists).
    static var user: AuthUser?
    
    // OIDC tokens of the user.
    var tokens: TokenSet
    
    // User information.
    var id: String
    var name: String
    
    // The URL base this user was authorized from
    var authorizeUrl: NSURL
    
    // Serialization
    static let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.URLByAppendingPathComponent("auth_user")
    
    init(tokens: TokenSet, id: String, name: String, authorizeUrl: NSURL) {
        
        self.tokens = tokens
        self.id = id
        self.name = name
        self.authorizeUrl = authorizeUrl
        
        super.init()
    }
    
    required convenience init?(coder aCoder: NSCoder) {
        do {
            let tokens = TokenSet(
                access: try (aCoder.decodeObjectForKey("accessToken") as? String).unwrap(),
                expires: try (aCoder.decodeObjectForKey("expires") as? NSDate).unwrap(),
                refresh: aCoder.decodeObjectForKey("refreshToken") as? String)
        
            let id = try (aCoder.decodeObjectForKey("id") as? String).unwrap()
            let name = try (aCoder.decodeObjectForKey("name") as? String).unwrap()
            let authorizeUrl = try (aCoder.decodeObjectForKey("authorizeUrl") as? NSURL).unwrap()
         
            self.init(tokens: tokens, id: id, name: name, authorizeUrl: authorizeUrl)
        } catch {
            return nil
        }
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.tokens.access, forKey: "accessToken")
        aCoder.encodeObject(self.tokens.expires, forKey: "expires")
        aCoder.encodeObject(self.tokens.refresh, forKey: "refreshToken")
        
        aCoder.encodeObject(self.id, forKey: "id")
        aCoder.encodeObject(self.name, forKey: "name")
        aCoder.encodeObject(self.authorizeUrl, forKey: "authorizeUrl")
    }
}
