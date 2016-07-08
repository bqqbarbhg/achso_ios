
import Alamofire


class VideoExporter {
    let endpoint: NSURL
    
    init(endpoint: NSURL) {
        self.endpoint = endpoint
    }
    
    func exportVideos(videos: [Video], email: String) {
        
        var videosAsJson = [JSONObject]()
        
        for video in videos {
           videosAsJson.append(video.toManifest())
        }
        
        let jsonObject: [ String: AnyObject] = [
            "email": email,
            "videos": videosAsJson
        ]
        
        Session.doAuthenticated() { result in
            
            guard let http = result.http else {
                return
            }
            
            let request = self.endpoint.request(.POST, "/", json: jsonObject)
            http.authorizedRequestJSON(request, canRetry: false) { response in
                switch response.result {
                case .Failure(let error):
                    NSLog(error.localizedDescription)
                case .Success(let value) :
                    do {
                        let json = try (value as? JSONObject).unwrap()
                        let message: String = try json.castGet("message")
                        NSLog(message)
                    } catch {
                    }
                }
            }
        }
    }
}
