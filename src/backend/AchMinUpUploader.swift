/*

API wrapper for achminup, see https://github.com/bqqbarbhg/achminup

Achminup or "acsho minimal uploader" is just a simple PHP script that receives files, so it does not generate thumbnails. Uploading is done using simple HTTP post.

Note: This has no authentication.

*/


import Alamofire

class AchMinUpUploader: VideoUploader, ThumbnailUploader {
    
    let endpoint: NSURL
    
    init(endpoint: NSURL) {
        self.endpoint = endpoint
    }
    
    func uploadFile(sourceUrl: NSURL, id: NSUUID, type: String, progressCallback: (Float -> ())?, doneCallback: NSURL? -> ()) {
        
        Session.doAuthenticated() { result in
            
            guard let http = result.http else {
                doneCallback(nil)
                return
            }
            
            let request = http.authorizeRequest(self.endpoint.request(.POST, type))
            Alamofire.upload(request.method, request.url, headers: request.headers, file: sourceUrl)
                .progress { delta, total, expectedTotal in
                    progressCallback?(Float(total) / Float(expectedTotal))
                }
                .responseString { response in
                    
                    if let _ = response.result.error {
                        doneCallback(nil)
                        return
                    }
                    
                    let urlString = response.result.value?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    if let url = urlString.flatMap({ NSURL(string: $0) }) {
                        doneCallback(url)
                    } else {
                        doneCallback(nil)
                    }
            }
  
        }
    }
    
    func uploadVideo(video: Video, progressCallback: Float -> (), doneCallback: VideoUploadResult? -> ()) {
        guard let uri = video.videoUri.realUrl else {
            doneCallback(nil)
            return
        }
        
        uploadFile(uri, id: video.id, type: "videos", progressCallback: progressCallback, doneCallback: { url in
            doneCallback(url.flatMap { VideoUploadResult($0, nil, nil) })
        })
    }
    
    func uploadThumbnail(video: Video, progressCallback: Float -> (), doneCallback: NSURL? -> ()) {
        guard let uri = video.thumbnailUri.realUrl else {
            doneCallback(nil)
            return
        }
        
        uploadFile(uri, id: video.id, type: "thumbnails", progressCallback: progressCallback, doneCallback: doneCallback)
    }
}
