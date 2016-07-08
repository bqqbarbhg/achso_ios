
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
        
        let finalJson = stringifyJson(jsonObject)
        NSLog(finalJson!)
    }
}
