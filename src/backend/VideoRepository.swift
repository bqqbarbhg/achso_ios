/*

VideoRepository manages the uploading and downloading of videos and groups.

`refresh()` performs a local update that is quite fast and simple. It just loads the entities from core data.

`refreshOnline()` does a full online sync which is complicated and slow (asynchronously).
It uses Tasks.swift to break the operation into smaller chunks. The operations are roughly as follows:

- Download a list of all groups
- Donwload a list of all videos and compare their versions to the local ones
- Upload videos which are modified locally (server handles merging conflicts)
- Download videos that are more recent on the server

`uploadVideo(...)` uploads the video and thumbnail data in addition to the manifest data. The asynchronous HTTP methods make this function more complicated than it should be and it ended up as a delicate dance between background threads, callbacks and semaphores.

Uses AchRails.swift and Uploader.swift for connecting to the servers.

*/

import UIKit

protocol VideoRepositoryListener: class {
    func videoRepositoryUpdateStart()
    func videoRepositoryUpdateProgress(done: Int, total: Int)
    func videoRepositoryUpdated()
}

extension VideoRepositoryListener {
    func videoRepositoryUpdateStart() {}
    func videoRepositoryUpdateProgress(done: Int, total: Int) {}
}

enum CollectionIdentifier {
    case AllVideos
    case Group(String)
    case QrSearch(String)
}

class VideoRepository {
    
    // APIs
    var achRails: AchRails?
    var videoExporter: VideoExporter?
    var videoUploaders: [VideoUploader] = []
    var thumbnailUploaders: [ThumbnailUploader] = []
    
    // Cached entities
    var videoInfos: [VideoInfo] = []
    var groups: [Group] = []
    var user: User = User.localUser
    
    // Collections
    var allVideosCollection: Collection?
    var groupCollections: [String: Collection] = [:]
    
    // Listeners
    var listeners: [VideoRepositoryListener] = []
    var progressMax: Int = 0
    var progressDone: Int = 0
    
    // State
    var isOnlineRefreshing: Bool = false
    
    // Load the persisted entities.
    func refresh() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        if let videoInfos = try? appDelegate.getVideoInfos() {
            self.videoInfos = videoInfos
        }
        
        if let groupList = appDelegate.loadGroups() {
            self.groups = groupList.groups
            self.user = groupList.user
        } else {
            self.groups = []
            self.user = User.localUser
        }
        
        self.allVideosCollection = Collection(videos: videoInfos,
            title: NSLocalizedString("all_videos", comment: "Category for all videos"))
        
        var groupCollections: [String: Collection] = [:]
        for group in groups {
            
            let videos = group.videos.flatMap { id in
                return self.findVideoInfo(id)
            }.sort({ $0.creationDate > $1.creationDate })
            
            groupCollections[group.id] = Collection(videos: videos,
                title: group.name,
                subtitle: group.groupDescription)
        }
        self.groupCollections = groupCollections
        
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
                
                var numberOfTasks: Int = 0
                
                for videoRevision in videoRevisions {
                    if self.updateVideoIfNeeded(videoRevision) {
                        numberOfTasks += 1
                    }
                }
                
                self.ctx.videoRepository.progressBegin(numberOfTasks)
                
                self.done()
            }
        }
        
        func updateVideoIfNeeded(videoRevision: VideoRevision) -> Bool {
            if let localVideoInfo = self.videoRepository.findVideoInfo(videoRevision.id) {
                
                // Video found locally, check if it needs to be synced
                
                if localVideoInfo.hasLocalModifications {
                    
                    // Video has been modified locally: upload, merge in the server, and download the result.
                    self.uploadVideo(videoRevision)
                    return true
                    
                } else if videoRevision.revision > localVideoInfo.revision {
                    
                    // Video has been updated remotely, but not modified locally: Just download and overwrite.
                    self.downloadVideo(videoRevision)
                    return true
                    
                } else {
                    // Video up to date: Nothing to do
                }
            } else {
                // No local video yet: download it
                self.downloadVideo(videoRevision)
                return true
            }
            
            return false
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
            
            self.achRails.getVideo(self.videoRevision.id) { tryVideo in
                
                self.ctx.videoRepository.progressAdvance()
                
                switch tryVideo {
                case .Error(let error): self.fail(error)
                case .Success(let video):
                    dispatch_async(dispatch_get_main_queue()) {
                        do {
                            try AppDelegate.instance.saveVideo(video, saveToDisk: false)
                            self.done()
                        } catch {
                            self.fail(error)
                        }
                    }
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
                    
                    self.ctx.videoRepository.progressAdvance()
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        switch tryVideo {
                        case .Error(let error): self.fail(error)
                        case .Success(let video):
                            do {
                                try AppDelegate.instance.saveVideo(video, saveToDisk: false)
                                self.done()
                            } catch {
                                self.fail(error)
                            }
                        }
                    }
                    
                }
                
            } catch {
                self.ctx.videoRepository.progressAdvance()
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
                    
                case .Success(let (groups, user)):
                    dispatch_async(dispatch_get_main_queue()) {
                        AppDelegate.instance.saveGroups(groups, user: user, downloadedBy: self.achRails.userId)
                        self.done()
                    }
                }
            }
        }
        
    }
    
    // Download and persist new entities from the server.
    func refreshOnline() -> Bool {
        guard let achRails = self.achRails else { return false }
        let ctx = RepoContext(achRails: achRails, videoRepository: self)
        
        // TODO: Count these if many?
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        self.isOnlineRefreshing = true
        
        let task = RefreshOnlineTask(ctx)
        task.completionHandler = {
            AppDelegate.instance.saveContext()
            self.isOnlineRefreshing = false
            self.refresh()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
        task.start()
        
        return true
    }
    
    // Persists a video.
    func saveVideo(video: Video) throws {
        try AppDelegate.instance.saveVideo(video)
        refresh()
    }
    
    // Find a video by id.
    func findVideoInfo(id: NSUUID) -> VideoInfo? {
        for info in self.videoInfos {
            if info.id == id {
                return info
            }
        }
        return nil
    }
    
    // Checks if there has been changes to the video in the server and downloads them if necessary.
    // `callback` is called with a Video object if updated, nil if old.
    func refreshVideo(video: Video, isView: Bool, callback: Video? -> ()) {
        guard let achRails = self.achRails else {
            callback(nil)
            return
        }
        
        if video.videoUri.isLocal {
            callback(nil)
            return
        }
        
        if video.hasLocalModifications {
            achRails.uploadVideo(video) { tryVideo in
                callback(tryVideo.success)
            }
        } else {
            achRails.getVideo(video.id, ifNewerThanRevision: video.revision, isView: isView) { tryVideo in
                callback(tryVideo.success?.flatMap { $0 })
            }
        }
    }
    
    func getVideo(id: NSUUID, callback: Try<Video> -> ()) {
        if let _ = self.findVideoInfo(id) {
            do {
                let video = try AppDelegate.instance.getVideo(id).unwrap()
                callback(.Success(video))
            } catch {
                callback(.Error(error))
            }
            return
        }
        
        guard let achRails = self.achRails else {
            callback(.Error(UserError.notSignedIn.withDebugError("achrails not initialized")))
            return
        }
        
        achRails.getVideo(id) { tryVideo in
            switch tryVideo {
            case .Success(let video):
                do {
                    try AppDelegate.instance.saveVideo(video)
                    callback(.Success(video))
                } catch {
                    callback(.Error(error))
                }
            case .Error(let error):
                callback(.Error(error))

            }
            
        }
    }
    
    class DeleteVideosTask: RepoTask {
        
        let videos: [Video]
        
        init(_ ctx: RepoContext, videos: [Video]) {
            self.videos = videos
            super.init(ctx)
        }
        
        override func run() {
            
            for video in videos {
                let task = DeleteVideoTask(ctx, video: video)
                self.addSubtask(task)
                task.start()
            }
            
            self.done()
        }
    }
    
    class DeleteVideoTask: RepoTask {
        
        let video: Video
        
        init(_ ctx: RepoContext, video: Video) {
            self.video = video
            super.init(ctx)
        }
        
        override func run() {
            ctx.achRails.deleteVideo(self.video) { error in
                if let error = error {
                    self.fail(error)
                } else {
                    self.done()
                }
            }
        }
    }

    
    func exportVideos(videos: [Video], email: String, doneCallback: [ErrorType] -> ()) {
        self.videoExporter?.exportVideos(videos, email: email)
    }
    
    // Deletes videos from the server
    func deleteVideos(videos: [Video], doneCallback: [ErrorType] -> ()) {
        Session.doAuthenticated() { status in
            switch status {
            case .Error(let error):
                doneCallback([error])
                return
            default:
                break
            }
            
            guard let achRails = self.achRails else {
                doneCallback([UserError.invalidLayersBoxUrl.withDebugError("achrails not initialized")])
                return
            }

            let ctx = RepoContext(achRails: achRails, videoRepository: self)
            let task = DeleteVideosTask(ctx, videos: videos)

            task.completionHandler = {
                doneCallback(task.errors)
            }

            task.start()
        }
    }
    
    // Upload a video to servers.
    func uploadVideo(video: Video, progressCallback: (Float, animated: Bool) -> (), doneCallback: Try<Video> -> ()) {
        
        guard let achRails = self.achRails else {
            doneCallback(.Error(UserError.invalidLayersBoxUrl.withDebugError("achrails not initialized")))
            return
        }
        
        // The uploading is done as many sequential asynchronous calls so do the work on background thread and block until the asynchronous callback is called to get better structure.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let semaphore = dispatch_semaphore_create(0)
            
            var maybeVideoUrl: NSURL?
            var maybeThumbnailUrl: NSURL?
            var maybeDeleteUrl: NSURL?
            
            var progressBase: Float = 0.0
            
            // Iterate through possible video uploader services and try to upload, break out on first success.
            for videoUploader in self.videoUploaders {
                
                videoUploader.uploadVideo(video,
                    progressCallback:  { value in
                        
                        // Do progress updates on the main thread.
                        dispatch_async(dispatch_get_main_queue()) {
                            progressCallback(value * 0.7, animated: false)
                        }
                        
                    }, doneCallback: { result in
                        if let result = result {
                            maybeVideoUrl = result.video
                            maybeThumbnailUrl = result.thumbnail
                            maybeDeleteUrl = result.deleteUrl
                        }
                        
                        // Continue in the background thread.
                        dispatch_semaphore_signal(semaphore)
                    })
    
                // Block until the asynchronous upload is done.
                while dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 {
                    NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 1))
                }
                
                if maybeVideoUrl != nil {
                    break
                }
            }
            
            progressBase = 0.7
            
            // Iterate through possible thumbnail uploaders if the video upload didn't also produce a thumbnail.
            if maybeThumbnailUrl == nil && maybeVideoUrl != nil {
                for thumbnailUploader in self.thumbnailUploaders {
                    thumbnailUploader.uploadThumbnail(video,
                        progressCallback:  { value in
                            
                            // Do progress updates on the main thread.
                            dispatch_async(dispatch_get_main_queue()) {
                                progressCallback(progressBase + value * 0.1, animated: false)
                            }
                            
                        },
                        doneCallback: { result in
                            if let result = result {
                                maybeThumbnailUrl = result
                            }
                            
                            // Continue in the background thread.
                            dispatch_semaphore_signal(semaphore)
                        }
                    )

                    // Block until the asynchronous upload is done.
                    while dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 {
                        NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 1))
                    }
                    
                    if maybeThumbnailUrl != nil {
                        break
                    }
                }
                
                progressBase = 0.8
            }
            
            // Check that the video has now remote video and thumbnail URLs.
            guard let videoUrl = maybeVideoUrl, thumbnailUrl = maybeThumbnailUrl else {
                dispatch_async(dispatch_get_main_queue()) {
                    doneCallback(.Error(UserError.failedToUploadVideo.withDebugError("Failed to upload media")))
                }
                return
            }
            
            // Create a new video with the remote URLs.
            let newVideo = Video(copyFrom: video)
            newVideo.videoUri = videoUrl
            newVideo.thumbnailUri = thumbnailUrl
            newVideo.deleteUrl = maybeDeleteUrl
            
            achRails.uploadVideo(newVideo) { tryUploadedVideo in
                
                // Stop looping in the background thread.
                dispatch_semaphore_signal(semaphore)
                
                // Save the video in the main thread.
                dispatch_async(dispatch_get_main_queue()) {
                    progressCallback(1.0, animated: true)
                    
                    switch tryUploadedVideo {
                    case .Success(let uploadedVideo):
                        do {
                            try videoRepository.saveVideo(uploadedVideo)
                            
                            // Delete old video and thumbnail
                            let fileManager = NSFileManager.defaultManager()
                            try fileManager.removeItemAtURL(video.thumbnailUri.realUrl.unwrap())
                            try fileManager.removeItemAtURL(video.videoUri.realUrl.unwrap())
                            
                            doneCallback(.Success(uploadedVideo))
                        } catch {
                            doneCallback(.Error(UserError.failedToSaveVideo.withInnerError(error)))
                        }
                    case .Error(let error):
                        doneCallback(.Error(UserError.failedToUploadVideo.withInnerError(error)))
                    }
                }
            }
            
            // Spin this loop once per 0.5s and give some fake progress reports to indicate uploading.
            while dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 && progressBase <= 0.90 {
                progressBase += 0.05
                
                dispatch_async(dispatch_get_main_queue()) {
                    progressCallback(progressBase, animated: true)
                }
                
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 0.5))
            }
        }
    }
    
    // Returns a collection of videos described by `identifier`
    func retrieveCollectionByIdentifier(identifier: CollectionIdentifier) -> Collection? {
        switch identifier {
        case .AllVideos: return self.allVideosCollection
        case .Group(let id): return self.groupCollections[id]
        case .QrSearch(let code): return self.createQrCodeCollection(code)
        }
    }
    
    // Create a temporary collection containing videos tagged with the QR code `code`
    func createQrCodeCollection(code: String) -> Collection {
        let videos = self.videoInfos.filter({ $0.tag == code })
        return Collection(videos: videos, title: "QR: \(code)")
    }
    
    // MARK: - listeners

    func addListener(listener: VideoRepositoryListener) {
        self.listeners.append(listener)
        listener.videoRepositoryUpdated()
    }
    
    func removeListener(listener: VideoRepositoryListener) {
        if let index = self.listeners.indexOf({ $0 === listener}) {
            self.listeners.removeAtIndex(index)
        }
    }
    
    // Start reporting update progress to the listeners with `count` units.
    func progressBegin(count: Int) {
        dispatch_async(dispatch_get_main_queue()) {
            self.progressDone = 0
            self.progressMax = count
            for listener in self.listeners {
                listener.videoRepositoryUpdateStart()
            }
        }
    }
    
    // Report the completion of one unit of progress to the listeners.
    func progressAdvance() {
        dispatch_async(dispatch_get_main_queue()) {
            self.progressDone += 1
            for listener in self.listeners {
                listener.videoRepositoryUpdateProgress(self.progressDone, total: self.progressMax)
            }
        }
    }
}

var videoRepository = VideoRepository()
