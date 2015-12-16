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
    let userId: String
    
    init(http: AuthenticatedHTTP, endpoint: NSURL, userId: String) {
        self.http = http
        self.endpoint = endpoint
        self.userId = userId
    }
    
    func getVideos(callback: [VideoRevision]? -> ()) {
        
        http.authorizedRequestJSON(endpoint.request(.GET, "videos.json"), canRetry: true) { response in
            let videosJson = response.result.value?["videos"] as? JSONArray
            let videos = videosJson?.flatMap { try? VideoRevision(data: ($0 as? JSONObject).unwrap()) }
            callback(videos)
        }
        
    }
    
    func getVideo(id: NSUUID, callback: Try<Video> -> ()) {
        
        let request = endpoint.request(.GET, "videos/\(id.lowerUUIDString).json")
        http.authorizedRequestJSON(request, canRetry: true) { response in
            let videoJson = response.result.value as? JSONObject
            do {
                let video = try Video(manifest: videoJson.unwrap(), hasLocalModifications: false, downloadedBy: self.userId)
                callback(.Success(video))
            } catch {
                callback(.Error(error))
            }
        }
    }
    
    func getVideo(id: NSUUID, ifNewerThanRevision revision: Int, callback: Try<Video?> -> ()) {
        
        let request = endpoint.request(.GET, "videos/\(id.lowerUUIDString).json", parameters: ["newer_than_rev": String(revision)])
        http.authorizedRequestJSON(request, canRetry: true) { response in
            if response.response?.statusCode == 304 {
                callback(.Success(nil))
                return
            }
            
            let videoJson = response.result.value as? JSONObject
            do {
                let video = try Video(manifest: videoJson.unwrap(), hasLocalModifications: false, downloadedBy: self.userId)
                callback(.Success(video))
            } catch {
                callback(.Error(error))
            }
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
                    let video = try Video(manifest: (videoJson as? JSONObject).unwrap(), hasLocalModifications: false, downloadedBy: self.userId)
                    callback(.Success(video))
                } catch {
                    callback(.Error(error))
                }
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
