import Foundation

struct VideoRevision {
    let id: NSUUID
    let revision: Int
    
    init(data: JSONObject) throws {
        self.id = try NSUUID(UUIDString: data.castGet("uuid")).unwrap()
        self.revision = try data.castGet("revision")
    }
}

class AchRails {
    
    let http: AuthenticatedHTTP
    let endpoint: NSURL
    
    init(http: AuthenticatedHTTP, endpoint: NSURL) {
        self.http = http
        self.endpoint = endpoint
    }
    
    func getVideos(callback: [VideoRevision]? -> ()) {
        
        http.authorizedRequestJSON(endpoint.request(.GET, "videos.json"), canRetry: true) { response in
            let videosJson = response.result.value?["videos"] as? JSONArray
            let videos = videosJson?.flatMap { try? VideoRevision(data: ($0 as? JSONObject).unwrap()) }
            callback(videos)
        }
        
    }
    
    func getVideo(id: NSUUID, callback: Video? -> ()) {
        
        let request = endpoint.request(.GET, "videos/\(id.lowerUUIDString).json")
        http.authorizedRequestJSON(request, canRetry: true) { response in
            let videoJson = response.result.value as? JSONObject
            let video = try? Video(manifest: videoJson.unwrap())
            callback(video)
        }
    }
    
    func uploadVideo(video: Video, callback: Video? -> ()) {
        
        let manifest = video.toManifest()
        let request = endpoint.request(.PUT, "videos/\(video.id.lowerUUIDString).json", json: manifest)
        http.authorizedRequestJSON(request, canRetry: true) { response in
            let videoJson = response.result.value as? JSONObject
            let video = try? Video(manifest: videoJson.unwrap())
            callback(video)
        }
    }
}
