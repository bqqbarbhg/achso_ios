import Foundation

class User {
    
    var id: String
    var name: String
    var uri: String
    
    init() {
        self.id = ""
        self.name = ""
        self.uri = ""
    }
    
    init(manifest: JSONObject) throws {
        self.id = (manifest["id"] as? String) ?? ""
        self.name = (manifest["name"] as? String) ?? ""
        self.uri = (manifest["uri"] as? String) ?? ""
    }
    
    func toManifest() -> JSONObject {
        return [
            "id": self.id,
            "name": self.name,
            "uri": self.uri,
        ]
    }
}
