/*

API wrapper for go-video-transcoder, see https://github.com/bqqbarbhg/go-video-transcoder

*/


import Alamofire

class GoViTraUploader: VideoUploader {
    
    let endpoint: NSURL
    
    init(endpoint: NSURL) {
        self.endpoint = endpoint
    }
    
    func uploadVideo(video: Video, progressCallback: Float -> (), doneCallback: VideoUploadResult? -> ()) {
        guard let sourceUrl = video.videoUri.realUrl else {
            doneCallback(nil)
            return
        }
        
        Session.doAuthenticated() { result in
            
            guard let http = result.http else {
                doneCallback(nil)
                return
            }
            
            let request = http.authorizeRequest(self.endpoint.request(.POST, "/uploads"))
            Alamofire.upload(request.method, request.url, headers: request.headers, file: sourceUrl)
                .progress { delta, total, expectedTotal in
                    progressCallback(Float(total) / Float(expectedTotal))
                }
                .responseJSON { response in
                    
                    do {
                        let json = try (response.result.value as? JSONObject).unwrap()
                        let videoUrl = try NSURL(string: json.castGet("video")).unwrap()
                        let thumbUrl = try NSURL(string: json.castGet("thumbnail")).unwrap()
                        let deleteUrl = try NSURL(string: json.castGet("deleteUrl")).unwrap()
                        doneCallback(VideoUploadResult(video: videoUrl, thumbnail: thumbUrl, deleteUrl: deleteUrl))
                    } catch {
                        doneCallback(nil)
                    }
                }
        }
    }
}