import Foundation

class Video {
    typealias Location = (latitude: Double, longitude: Double, accuracy: Double)
    
    var title: String
    var annotations: [Annotation]
    var videoUri: NSURL
    var thumbnailUri: NSURL
    var id: NSUUID
    var revision: Int
    var formatVersion: Int
    var creationDate: NSDate
    var genre: String
    var rotation: Int
    var location: Location?
    var author: User
    
    var hasLocalModifications: Bool
    
    init(id: NSUUID, title: String, videoUri: NSURL, thumbnailUri: NSURL) {
        self.id = id
        self.title = title
        self.annotations = []
        self.videoUri = videoUri
        self.thumbnailUri = thumbnailUri
        self.revision = 0
        self.formatVersion = 1
        self.creationDate = NSDate()
        self.genre = "good_work" // TEMP!
        self.rotation = 0
        self.location = nil
        self.author = User()
        self.hasLocalModifications = true
    }
    
    init(copyFrom video: Video) {
        self.title = video.title
        self.annotations = video.annotations
        self.videoUri = video.videoUri
        self.thumbnailUri = video.thumbnailUri
        self.id = video.id
        self.revision = video.revision
        self.formatVersion = video.formatVersion
        self.creationDate = video.creationDate
        self.genre = video.genre
        self.rotation = video.rotation
        self.location = video.location
        self.author = video.author
        self.hasLocalModifications = video.hasLocalModifications
    }
    
    init(manifest: JSONObject, hasLocalModifications: Bool) throws {
        do {
            self.title = try manifest.castGet("title")
            self.id = try NSUUID(UUIDString: try manifest.castGet("id")).unwrap()
            self.videoUri = try NSURL(string: try manifest.castGet("videoUri")).unwrap()
            self.thumbnailUri = try NSURL(string: try manifest.castGet("thumbUri")).unwrap()
            self.revision = manifest["revision"] as? Int ?? 0
            self.formatVersion = manifest["formatVersion"] as? Int ?? 0
            self.creationDate = iso8601DateFormatter.dateFromString(try manifest.castGet("date")) ?? NSDate(timeIntervalSince1970: 0)
            self.genre = try manifest.castGet("genre")
            self.rotation = (manifest["rotation"] as? Int) ?? 0
            
            if let location = manifest["location"] as? JSONObject {
                self.location = try? Location(
                    latitude: location.castGet("latitude"),
                    longitude: location.castGet("longitude"),
                    accuracy: location.castGet("accuracy"))
            } else {
                self.location = nil
            }
            
            self.author = try User(manifest: manifest.castGet("author"))
            
            let annotations: [JSONObject] = try manifest.castGet("annotations")
            self.annotations = try annotations.map({ try Annotation(manifest: $0) })
            
            self.hasLocalModifications = hasLocalModifications
            
        } catch {
            // Swift-bug: Classes need to be initialized even if thrown
            self.title = ""
            self.annotations = []
            self.videoUri = NSURL()
            self.thumbnailUri = NSURL()
            self.id = NSUUID(UUIDBytes: [UInt8](count: 16, repeatedValue: 0x00))
            self.revision = 0
            self.formatVersion = 0
            self.creationDate = NSDate(timeIntervalSince1970: 0)
            self.genre = ""
            self.rotation = 0
            self.author = User()
            self.hasLocalModifications = false
            
            throw error
        }
    }
    
    func toManifest() -> JSONObject {
        return [
            "title": self.title,
            "annotations": self.annotations.map({ $0.toManifest() }),
            "videoUri": self.videoUri.absoluteString,
            "thumbUri": self.thumbnailUri.absoluteString,
            "id": self.id.lowerUUIDString,
            "date": iso8601DateFormatter.stringFromDate(self.creationDate),
            "revision": self.revision,
            "formatVersion": self.formatVersion,
            "genre": self.genre,
            "rotation": self.rotation,
            "location": self.location.map {
                [
                    "latitude": $0.latitude,
                    "longitude": $0.longitude,
                    "accuracy": $0.accuracy,
                ]
            } ?? NSNull(),
            "author": self.author.toManifest(),
        ]
    }
}