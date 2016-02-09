/*

Defines interfaces for uploading video and thumbnail data.

Video upload can potentially result in also a thumbnail if the service supports it, otherwise a separate thumbnail uploading service might be used.

*/

import Foundation

typealias VideoUploadResult = (video: NSURL, thumbnail: NSURL?)

protocol VideoUploader {
    func uploadVideo(video: Video, progressCallback: Float -> (), doneCallback: VideoUploadResult? -> ())
}

protocol ThumbnailUploader {
    func uploadThumbnail(video: Video, progressCallback: Float -> (), doneCallback: NSURL? -> ())
}

