import UIKit

class User: NSObject, NSCoding {
    
    var id: String
    var name: String
    var uri: String
    
    static var localUser: User = {
        return User(id: "", name: "Unknown", uri: "")
    }()
    
    override init() {
        self.id = ""
        self.name = ""
        self.uri = ""
        super.init()
    }
    
    init(id: String, name: String, uri: String) {
        self.id = id
        self.name = name
        self.uri = uri
        super.init()
    }
    
    init(manifest: JSONObject) throws {
        self.id = (manifest["id"] as? String) ?? ""
        self.name = (manifest["name"] as? String) ?? ""
        self.uri = (manifest["uri"] as? String) ?? ""
        super.init()
    }
    
    required convenience init?(coder aCoder: NSCoder) {
        
        do {
            let id = try (aCoder.decodeObjectForKey("id") as? String).unwrap()
            let name = try (aCoder.decodeObjectForKey("name") as? String).unwrap()
            let uri = try (aCoder.decodeObjectForKey("uri") as? String).unwrap()
            self.init(id: id, name: name, uri: uri)
        } catch {
            return nil
        }
    }

    func toManifest() -> JSONObject {
        return [
            "id": self.id,
            "name": self.name,
            "uri": self.uri,
        ]
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.id, forKey: "id")
        aCoder.encodeObject(self.name, forKey: "name")
        aCoder.encodeObject(self.uri, forKey: "uri")
    }
}
