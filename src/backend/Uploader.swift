import Foundation

typealias VideoUploadResult = (video: NSURL, thumbnail: NSURL?)

protocol VideoUploader {
    func uploadVideo(video: Video, progressCallback: Float -> (), doneCallback: VideoUploadResult? -> ())
}

protocol ThumbnailUploader {
    func uploadThumbnail(video: Video, progressCallback: Float -> (), doneCallback: NSURL? -> ())
}

