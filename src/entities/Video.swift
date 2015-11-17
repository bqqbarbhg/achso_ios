import Foundation

class Video {
    var title: String
    var annotations: [Annotation]
    var videoUri: NSURL
    var id: NSUUID
    
    init(title: String, videoUri: NSURL) {
        self.id = NSUUID()
        self.title = title
        self.annotations = []
        self.videoUri = videoUri
    }
    
    init(copyFrom video: Video) {
        self.title = video.title
        self.annotations = video.annotations
        self.videoUri = video.videoUri
        self.id = video.id
    }
    
    init(manifest: JSONObject) throws {
        do {
            self.title = try manifest.castGet("title")
            self.id = try NSUUID(UUIDString: try manifest.castGet("id")).unwrap()
            self.videoUri = try NSURL(string: try manifest.castGet("videoUri")).unwrap()
        
            let annotations: [JSONObject] = try manifest.castGet("annotations")
            self.annotations = try annotations.map({ try Annotation(manifest: $0) })
        } catch {
            // Swift-bug: Classes need to be initialized even if thrown
            self.title = ""
            self.annotations = []
            self.videoUri = NSURL()
            self.id = NSUUID(UUIDBytes: [UInt8](count: 16, repeatedValue: 0x00))

            throw error
        }
    }
    
    func toManifest() -> JSONObject {
        return [
            "title": self.title,
            "annotations": self.annotations.map({ $0.toManifest() }),
            "videoUri": self.videoUri.absoluteString,
            "id": self.id.lowerUUIDString,
        ]
    }
}