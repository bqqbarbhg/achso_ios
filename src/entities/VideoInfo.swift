import Foundation
import CoreData

class VideoInfo {
    var id: NSUUID
    var revision: Int
    var title: String
    var thumbnailUri: NSURL
    var creationDate: NSDate
    var genre: String
    
    var isLocal: Bool
    var hasLocalModifications: Bool
    var downloadedBy: String?
    
    init(video: Video) {
        self.id = video.id
        self.revision = video.revision
        self.title = video.title
        self.thumbnailUri = video.thumbnailUri
        self.isLocal = video.videoUri.scheme == "file"
        self.creationDate = video.creationDate
        self.genre = video.genre
        
        self.hasLocalModifications = video.hasLocalModifications
        self.downloadedBy = video.downloadedBy
    }
    
    init(object: NSManagedObject) throws {
        do {
            self.id = try NSUUID(UUIDString: (object.valueForKey("id") as? String).unwrap()).unwrap()
            self.revision = try (object.valueForKey("revision") as? Int).unwrap()
            self.title = try (object.valueForKey("title") as? String).unwrap()
            self.thumbnailUri = try NSURL(string: (object.valueForKey("thumbnailUri") as? String).unwrap()).unwrap()
            self.creationDate = try (object.valueForKey("creationDate") as? NSDate).unwrap()
            self.genre = try (object.valueForKey("genre") as? String).unwrap()
            
            self.isLocal = try (object.valueForKey("isLocal") as? Bool).unwrap()
            self.hasLocalModifications = try (object.valueForKey("hasLocalModifications") as? Bool).unwrap()
            self.downloadedBy = object.valueForKey("downloadedBy") as? String
        } catch {
            // Swift-bug: Classes need to be initialized even if thrown
            self.id = NSUUID(UUIDBytes: [UInt8](count: 16, repeatedValue: 0x00))
            self.revision = 0
            self.title = ""
            self.thumbnailUri = NSURL()
            self.creationDate = NSDate(timeIntervalSince1970: 0)
            self.genre = ""
            
            self.isLocal = false
            self.hasLocalModifications = false
            self.downloadedBy = nil
            
            throw error
        }
    }
    
    func writeToObject(object: NSManagedObject) {
        object.setValue(self.id.lowerUUIDString, forKey: "id")
        object.setValue(self.revision, forKey: "revision")
        object.setValue(self.title, forKey: "title")
        object.setValue(self.thumbnailUri.absoluteString, forKey: "thumbnailUri")
        object.setValue(self.isLocal, forKey: "isLocal")
        object.setValue(self.creationDate, forKey: "creationDate")
        object.setValue(self.hasLocalModifications, forKey: "hasLocalModifications")
        object.setValue(self.genre, forKey: "genre")
        object.setValue(self.downloadedBy, forKey: "downloadedBy")
    }
}
