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
        let baseUrl = endpoint.URLByAppendingPathComponent("upload.php")
        guard let components = NSURLComponents(URL: baseUrl, resolvingAgainstBaseURL: false) else {
            doneCallback(nil)
            return
        }
        components.queryItems = (components.queryItems ?? []) + [
            NSURLQueryItem(name: "id", value: id.lowerUUIDString),
            NSURLQueryItem(name: "type", value: type),
        ]
        
        Alamofire.upload(.POST, components, file: sourceUrl)
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
    
    func uploadVideo(video: Video, progressCallback: Float -> (), doneCallback: VideoUploadResult? -> ()) {
        guard let uri = video.videoUri.realUrl else {
            doneCallback(nil)
            return
        }
        
        uploadFile(uri, id: video.id, type: "video", progressCallback: progressCallback, doneCallback: { url in
            doneCallback(url.flatMap { VideoUploadResult($0, nil) })
        })
    }
    
    func uploadThumbnail(video: Video, progressCallback: Float -> (), doneCallback: NSURL? -> ()) {
        guard let uri = video.thumbnailUri.realUrl else {
            doneCallback(nil)
            return
        }
        
        uploadFile(uri, id: video.id, type: "thumbnail", progressCallback: progressCallback, doneCallback: doneCallback)
    }
}
