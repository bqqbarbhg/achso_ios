import Foundation

class AuthUser: NSObject, NSCoding {

    static var user: AuthUser?
    
    var tokens: TokenSet
    
    var id: String
    var name: String
    
    static let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.URLByAppendingPathComponent("auth_user")
    
    init(tokens: TokenSet, id: String, name: String) {
        
        self.tokens = tokens
        self.id = id
        self.name = name
        
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
         
            self.init(tokens: tokens, id: id, name: name)
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
    }
}
