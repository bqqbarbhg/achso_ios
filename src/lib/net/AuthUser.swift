/*

AuthUser is an object describing an user session.

It also defines serialization and deserialization methods for storing user state when closing the app.

*/

import Foundation

// Represents an authenticated user.
class AuthUser: NSObject, NSCoding {
    
    // Session token of the user.
    var session: String
    
    // User information.
    var id: String
    var name: String
    
    // The URL base this user was authorized from
    var authorizeUrl: NSURL
    
    init(session: String, id: String, name: String, authorizeUrl: NSURL) {
        
        self.session = session
        self.id = id
        self.name = name
        self.authorizeUrl = authorizeUrl
        
        super.init()
    }
    
    required convenience init?(coder aCoder: NSCoder) {
        do {
            let session = try (aCoder.decodeObjectForKey("session") as? String).unwrap()
            let id = try (aCoder.decodeObjectForKey("id") as? String).unwrap()
            let name = try (aCoder.decodeObjectForKey("name") as? String).unwrap()
            let authorizeUrl = try (aCoder.decodeObjectForKey("authorizeUrl") as? NSURL).unwrap()
         
            self.init(session: session, id: id, name: name, authorizeUrl: authorizeUrl)
        } catch {
            return nil
        }
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.session, forKey: "session")
        aCoder.encodeObject(self.id, forKey: "id")
        aCoder.encodeObject(self.name, forKey: "name")
        aCoder.encodeObject(self.authorizeUrl, forKey: "authorizeUrl")
    }
}
