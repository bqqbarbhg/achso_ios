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
            let video = try? Video(manifest: videoJson.unwrap(), hasLocalModifications: false)
            callback(video)
        }
    }
    
    func uploadVideo(video: Video, callback: Try<Video> -> ()) {
        
        let manifest = video.toManifest()
        let request = endpoint.request(.PUT, "videos/\(video.id.lowerUUIDString).json", json: manifest)
        http.authorizedRequestJSON(request, canRetry: true) { response in
            switch response.result {
            case .Failure(let error):
                callback(.Error(error))
            case .Success(let videoJson):
                do {
                    let video = try Video(manifest: (videoJson as? JSONObject).unwrap(), hasLocalModifications: false)
                    callback(.Success(video))
                } catch {
                    callback(.Error(error))
                }
            }
            
        }
    }
    
    class Group {
        var name: String
        var description: String
        var videos: [NSUUID]
        
        init(manifest: JSONObject) throws {
            do {
                self.name = try manifest.castGet("name")
                self.description = try manifest.castGet("description")
                
                let videos: JSONArray = try manifest.castGet("videos")
                self.videos = videos.flatMap {
                    guard let string = $0 as? String else { return nil }
                    return NSUUID(UUIDString: string)
                }
                
            } catch {
                self.name = ""
                self.description = ""
                self.videos = []
            }
        }
    }
    
    func getGroups(callback: Try<[Group]> -> ()) {
        
        let request = endpoint.request(.GET, "groups.json")
        http.authorizedRequestJSON(request, canRetry: true) { response in
            switch response.result {
            case .Failure(let error):
                callback(.Error(error))
            case .Success(let groupsJson):
                if let groupsArray: JSONArray = groupsJson["groups"] as? JSONArray {
                    
                    let groups = groupsArray.flatMap { any -> Group? in
                        guard let jsonObject = any as? JSONObject else { return nil }
                        return try? Group(manifest: jsonObject)
                    }
                    
                    callback(.Success(groups))
                } else {
                    callback(.Error(DebugError("Expected groups")))
                }
            }
        }
    }
}
