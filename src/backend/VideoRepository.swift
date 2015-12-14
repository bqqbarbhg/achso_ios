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
    
    var groups: [Group] = []
    
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
        
        if let groups = appDelegate.loadGroups() {
            self.groups = groups
        }
        
        let allVideosTitle = NSLocalizedString("all_videos", comment: "Category for all videos")
        let generalCollection = Collection(title: allVideosTitle, type: .General)
        generalCollection.videos = videoInfos
        
        let groupCollections: [Collection] = groups.map { group in
            let collection = Collection(title: group.name, type: .Group, extra: group)
            
            collection.videos = group.videos.flatMap { id in
                return self.findVideoInfo(id)
            }
            
            return collection
        }
        
        self.collections = [generalCollection] + groupCollections
        
        for listener in self.listeners {
            listener.videoRepositoryUpdated()
        }
    }
    
    typealias RepoContext = (achRails: AchRails, videoRepository: VideoRepository)
    
    class RepoTask: Task {
        let ctx: RepoContext
        
        var achRails: AchRails {
            return ctx.achRails
        }

        var videoRepository: VideoRepository {
            return ctx.videoRepository
        }
        
        init(_ ctx: RepoContext) {
            self.ctx = ctx
        }
    }
    
    class RefreshOnlineTask: RepoTask {
        
        override func run() {
            
            let getVideosTask = GetVideosTask(ctx)
            let getGroupsTask = GetGroupsTask(ctx)
            
            self.addSubtask(getVideosTask)
            self.addSubtask(getGroupsTask)
            
            getVideosTask.start()
            getGroupsTask.start()
            
            self.done()
        }
    }
    
    class GetVideosTask: RepoTask {
        
        override func run() {
            self.achRails.getVideos() {
                
                guard let videoRevisions = $0 else {
                    self.fail(DebugError("Failed to retrieve videos"))
                    return
                }
                
                for videoRevision in videoRevisions {
                    self.updateVideoIfNeeded(videoRevision)
                }
                
                self.done()
            }
        }
        
        func updateVideoIfNeeded(videoRevision: VideoRevision) {
            if let localVideoInfo = self.videoRepository.findVideoInfo(videoRevision.id) {
                
                // Video found locally, check if it needs to be synced
                
                if localVideoInfo.hasLocalModifications {
                    
                    // Video has been modified locally: upload, merge in the server, and download the result.
                    self.uploadVideo(videoRevision)
                    
                } else if videoRevision.revision > localVideoInfo.revision {
                    
                    // Video has been updated remotely, but not modified locally: Just download and overwrite.
                    self.downloadVideo(videoRevision)
                    
                } else {
                    // Video up to date: Nothing to do
                }
            } else {
                // No local video yet: download it
                self.downloadVideo(videoRevision)
            }
            
        }

        func downloadVideo(videoRevision: VideoRevision) {
            
            let task = DownloadVideoTask(ctx, videoRevision: videoRevision)
            self.addSubtask(task)
            task.start()
            
        }
        
        func uploadVideo(videoRevision: VideoRevision) {
            
            let task = UploadVideoTask(ctx, videoRevision: videoRevision)
            self.addSubtask(task)
            task.start()
            
        }
    }
    
    class DownloadVideoTask: RepoTask {
        
        let videoRevision: VideoRevision
        
        init(_ ctx: RepoContext, videoRevision: VideoRevision) {
            self.videoRevision = videoRevision
            super.init(ctx)
        }
        
        override func run() {
            
            self.achRails.getVideo(self.videoRevision.id) {
                guard let video = $0 else {
                    self.fail(DebugError("Failed to retrieve video \(self.videoRevision.id)"))
                    return
                }
                
                do {
                    try AppDelegate.instance.saveVideo(video)
                    self.done()
                } catch {
                    self.fail(error)
                }
            }
            
        }
    }
    
    class UploadVideoTask: RepoTask {
        let videoRevision: VideoRevision
        
        init(_ ctx: RepoContext, videoRevision: VideoRevision) {
            self.videoRevision = videoRevision
            super.init(ctx)
        }
        
        override func run() {
            do {
                let maybeVideo = try AppDelegate.instance.getVideo(self.videoRevision.id)
                
                guard let video = maybeVideo else {
                    throw DebugError("Video not found locally")
                }
                
                self.achRails.uploadVideo(video) { tryVideo in
                    
                    switch tryVideo {
                    case .Error(let error): self.fail(error)
                    case .Success(let video):
                        do {
                            try AppDelegate.instance.saveVideo(video)
                            self.done()
                        } catch {
                            self.fail(error)
                        }
                    }
                    
                }
                
            } catch {
                self.fail(error)
            }
        }
    }
    
    class GetGroupsTask: RepoTask {
        
        override func run() {
            achRails.getGroups() { tryGroups in
                switch tryGroups {
                case .Error(let error):
                    self.fail(error)
                    
                case .Success(let groups):
                    AppDelegate.instance.saveGroups(groups, downloadedBy: self.achRails.userId)
                    self.done()
                }
            }
        }
        
    }
    
    func refreshOnline() -> Bool {
        guard let achRails = self.achRails else { return false }
        let ctx = RepoContext(achRails: achRails, videoRepository: self)
        
        // TODO: Count these if many?
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        let task = RefreshOnlineTask(ctx)
        task.completionHandler = {
            self.refresh()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
        task.start()
        
        return true
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
    
    func uploadVideo(video: Video, progressCallback: (Float, animated: Bool) -> (), doneCallback: Try<Video> -> ()) {
        
        guard let achRails = self.achRails else {
            doneCallback(.Error(UserError.invalidLayersBoxUrl.withDebugError("achrails not initialized")))
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
