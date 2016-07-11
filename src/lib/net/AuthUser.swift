/*

AuthUser is an object describing an OIDC user session. It owns the `TokenSet` used to make authenticated HTTP requests.

It also defines serialization and deserialization methods for storing user state when closing the app.

*/

import Foundation

// Represents an authenticated OIDC user.
class AuthUser: NSObject, NSCoding {
    
    // OIDC tokens of the user.
    var tokens: TokenSet
    
    // User information.
    var id: String
    var name: String
    var email: String
    
    // The URL base this user was authorized from
    var authorizeUrl: NSURL
    
    init(tokens: TokenSet, id: String, name: String, email: String, authorizeUrl: NSURL) {
        
        self.tokens = tokens
        self.id = id
        self.email = email
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
            let email = try (aCoder.decodeObjectForKey("email") as? String).unwrap()
            let authorizeUrl = try (aCoder.decodeObjectForKey("authorizeUrl") as? NSURL).unwrap()
            self.init(tokens: tokens, id: id, name: name, email: email, authorizeUrl: authorizeUrl)
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
        aCoder.encodeObject(self.email, forKey: "email")
        aCoder.encodeObject(self.authorizeUrl, forKey: "authorizeUrl")
    }
}
