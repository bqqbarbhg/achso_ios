import UIKit

protocol VideoRepositoryListener: class {
    func videoRepositoryUpdated()
}

class VideoRepository {
    
    var achRails: AchRails?
    var videoInfos: [VideoInfo] = []
    var videoUploaders: [VideoUploader] = []
    var thumbnailUploaders: [ThumbnailUploader] = []

    var collections: [Collection] = []
    var listeners: [VideoRepositoryListener] = []
    
    func addListener(listener: VideoRepositoryListener) {
        self.listeners.append(listener)
        listener.videoRepositoryUpdated()
    }
    
    func removeListener(listener: VideoRepositoryListener) {
        if let index = self.listeners.indexOf({ $0 === listener}) {
            self.listeners.removeAtIndex(index)
        }
    }
    
    func refresh() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        if let videoInfos = try? appDelegate.getVideoInfos() {
            self.videoInfos = videoInfos
        }
        
        let tempCollection = Collection(title: "All videos")
        tempCollection.videos = videoInfos
        self.collections = [tempCollection]
        
        for listener in self.listeners {
            listener.videoRepositoryUpdated()
        }
    }
    
    func refreshOnline() {
        if let achRails = self.achRails {
            achRails.getVideos() { videoRevisions in
                if let revisions = videoRevisions {
                    self.updateVideos(revisions)
                }
            }
        }
    }
    
    func saveVideo(video: Video) throws {
        try AppDelegate.instance.saveVideo(video)
        refresh()
    }
    
    func findVideoInfo(id: NSUUID) -> VideoInfo? {
        for info in self.videoInfos {
            if info.id == id {
                return info
            }
        }
        return nil
    }
    
    func updateVideos(revisions: [VideoRevision]) {
        guard let achRails = self.achRails else { return }
        
        for revision in revisions {
            if let video = self.findVideoInfo(revision.id) {
                if revision.revision <= video.revision { continue }
                
                achRails.getVideo(revision.id) { video in
                    if let video = video {
                        self.updateVideo(video)
                    }
                }
                
            } else {
                achRails.getVideo(revision.id) { video in
                    if let video = video {
                        self.updateVideo(video)
                    }
                }
            }
        }
    }
    
    func updateVideo(video: Video) {
        do {
            try self.saveVideo(video)
        } catch {
            // TODO
        }
    }
    
    func uploadVideo(video: Video, progressCallback: (Float, animated: Bool) -> (), doneCallback: Try<Video> -> ()) {
        
        guard let achRails = self.achRails else {
            doneCallback(.Error(UserError.failedToUploadVideo.withDebugError("achrails not initialized")))
            return
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let semaphore = dispatch_semaphore_create(0)
            
            var maybeVideoUrl: NSURL?
            var maybeThumbnailUrl: NSURL?
            
            var progressBase: Float = 0.0
            
            for videoUploader in self.videoUploaders {
                
                videoUploader.uploadVideo(video,
                    progressCallback:  { value in
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            progressCallback(value * 0.7, animated: false)
                        }
                        
                    }, doneCallback: { result in
                        if let result = result {
                            maybeVideoUrl = result.video
                            maybeThumbnailUrl = result.thumbnail
                        }
                        
                        dispatch_semaphore_signal(semaphore)
                    })
    
                while dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 {
                    NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 1))
                }
                
                if maybeVideoUrl != nil {
                    break
                }
            }
            
            progressBase = 0.7
            
            if maybeThumbnailUrl == nil {
                for thumbnailUploader in self.thumbnailUploaders {
                    thumbnailUploader.uploadThumbnail(video,
                        progressCallback:  { value in
                            
                            dispatch_async(dispatch_get_main_queue()) {
                                progressCallback(progressBase + value * 0.1, animated: false)
                            }
                            
                        },
                        doneCallback: { result in
                            if let result = result {
                                maybeThumbnailUrl = result
                            }
                            dispatch_semaphore_signal(semaphore)
                        }
                    )
                    
                    while dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 {
                        NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 1))
                    }
                    
                    if maybeThumbnailUrl != nil {
                        break
                    }
                }
                
                progressBase = 0.8
            }
            
            
            
            guard let videoUrl = maybeVideoUrl, thumbnailUrl = maybeThumbnailUrl else {
                dispatch_async(dispatch_get_main_queue()) {
                    doneCallback(.Error(UserError.failedToUploadVideo.withDebugError("Failed to upload media")))
                }
                return
            }
            
            let newVideo = Video(copyFrom: video)
            newVideo.videoUri = videoUrl
            newVideo.thumbnailUri = thumbnailUrl
            
            achRails.uploadVideo(newVideo) { tryUploadedVideo in
                dispatch_semaphore_signal(semaphore)
                
                dispatch_async(dispatch_get_main_queue()) {
                    progressCallback(1.0, animated: true)
                    switch tryUploadedVideo {
                    case .Success(let uploadedVideo):
                        do {
                            try videoRepository.saveVideo(uploadedVideo)
                            doneCallback(.Success(uploadedVideo))
                        } catch {
                            doneCallback(.Error(UserError.failedToSaveVideo.withInnerError(error)))
                        }
                    case .Error(let error):
                        doneCallback(.Error(UserError.failedToUploadVideo.withInnerError(error)))
                    }
                }
            }
            
            while dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 && progressBase <= 0.90 {
                progressBase += 0.05
                
                dispatch_async(dispatch_get_main_queue()) {
                    progressCallback(progressBase, animated: true)
                }
                
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 0.5))
            }
        }
    }
}

var videoRepository = VideoRepository()
