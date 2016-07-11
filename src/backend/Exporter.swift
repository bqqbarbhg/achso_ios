
import Alamofire


class VideoExporter {
    let endpoint: NSURL
    
    init(endpoint: NSURL) {
        self.endpoint = endpoint
    }
    
    func exportVideos(videos: [Video], email: String, callback: Try<String> -> ()) {
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
            http.authorizedRequestJSON(request, canRetry: true) { response in
                switch response.result {
                case .Failure(let error):
                    callback(.Error(error))
                    break
                case .Success(let value):
                    do {
                        let json = try (value as? JSONObject).unwrap()
                        let message: String = try json.castGet("message")
                        // Alamofire considers all finished requests as being succesful,
                        // therefore, a status code check is in order here.
                        if let statusCode = response.response?.statusCode {
                            if statusCode != 201 {
                                let error = NSError(domain: "com.legroup.achso!", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: message])
                                
                                callback(.Error(error))
                            } else {
                                callback(.Success(message))
                            }
                        }
                    } catch {
                        let error = NSError(domain: "com.legroup.achso!", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "Parsing JSON response failed!" ])
                        
                        callback(.Error(error))
                    }
                    break
                }
            }
        }
    }
}
