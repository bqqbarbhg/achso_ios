import Foundation
import CoreData

class Group: NSObject, NSCoding {
    var name: String = ""
    var groupDescription: String = ""
    var videos: [NSUUID] = []
    
    init(manifest: JSONObject) throws {
        super.init()
        
        do {
            self.name = try manifest.castGet("name")
            self.groupDescription = try manifest.castGet("description")
            
            let videos: JSONArray = try manifest.castGet("videos")
            self.videos = videos.flatMap {
                guard let string = $0 as? String else { return nil }
                return NSUUID(UUIDString: string)
            }

        } catch {
            throw error
        }
    }
    
    required init?(coder aCoder: NSCoder) {
        super.init()
        
        do {
            self.name = try (aCoder.decodeObjectForKey("name") as? String).unwrap()
            self.groupDescription = try (aCoder.decodeObjectForKey("description") as? String).unwrap()
            self.videos = try (aCoder.decodeObjectForKey("videos") as? [NSUUID]).unwrap()    
        } catch {
            return nil
        }
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.name, forKey: "name")
        aCoder.encodeObject(self.groupDescription, forKey: "description")
        aCoder.encodeObject(self.videos, forKey: "videos")
    }

}