import UIKit
import MobileCoreServices
import AssetsLibrary
import CoreLocation
import AVFoundation

enum VideoRecordType {
    case Record
    case Import
}

class VideoRecorder: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    // The delegate references are weak, so we need to store the active recorder so it doesn't get GC'd
    static var activeVideoRecorder: VideoRecorder?
    
    // Present a video recording view to the user
    static func recordVideo(viewController viewController: UIViewController, callback: (Try<Video>, VideoRecordType) -> ()) {
        let recorder = VideoRecorder(viewController: viewController, callback: callback, type: .Record)
        activeVideoRecorder = recorder
        recorder.doRecordVideo()
    }
    
    // Present a video importing view to the user
    static func importVideo(viewController viewController: UIViewController, callback: (Try<Video>, VideoRecordType) -> ()) {
        let recorder = VideoRecorder(viewController: viewController, callback: callback, type: .Import)
        activeVideoRecorder = recorder
        recorder.doImportVideo()
    }
    
    let viewController: UIViewController
    let userCallback: (Try<Video>, VideoRecordType) -> ()
    let type: VideoRecordType
    
    private init(viewController: UIViewController, callback: (Try<Video>, VideoRecordType) -> (), type: VideoRecordType) {
        self.viewController = viewController
        self.userCallback = callback
        self.type = type
    }
    
    func callback(video: Try<Video>) {
        self.userCallback(video, self.type)
    }
    
    private func doRecordVideo() {
        authorizeCamera() { granted in
            if !granted {
                VideoRecorder.activeVideoRecorder = nil
                self.callback(.Error(UserError.permissionsMissing([.Camera])))
                return
            }
            
            self.doRecordVideoAuthorized()
        }
    }
    
    private func doImportVideo() {
        
        switch ALAssetsLibrary.authorizationStatus() {
        case .Denied, .Restricted:
            callback(.Error(UserError.permissionsMissing([.VideoLibrary])))
            return
        default:
            break
        }
        
        // Use UIImagePickerController to import the video
        let imagePicker = UIImagePickerController()
        
        imagePicker.mediaTypes = [String(kUTTypeMovie)]
        imagePicker.sourceType = .PhotoLibrary
        
        imagePicker.delegate = self
        viewController.presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    private func doRecordVideoAuthorized() {
        // The location retrieving takes some time to get accurate,
        // so do it in background while the user is recording the video
        LocationRetriever.instance.startRetrievingLocation(self.startRecordingVideo)
    }
    
    private func startRecordingVideo(_didAuthorizeLoacting: Bool) {
        
        // Use UIImagePickerController for the recording, if more features are required,
        // such as pausing during recording, a custom view has to be created.
        let imagePicker = UIImagePickerController()
        imagePicker.mediaTypes = [String(kUTTypeMovie)]
        
        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            
            // Default to rear camera
            imagePicker.sourceType = .Camera
            imagePicker.cameraCaptureMode = .Video
            imagePicker.cameraDevice = .Rear
        } else {
            
            // Use image library when camera is not available (in emulator)
            imagePicker.sourceType = .PhotoLibrary
        }
        imagePicker.delegate = self
        viewController.presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        // Delegate callback called, no need to keep the reference anymore
        VideoRecorder.activeVideoRecorder = nil
        
        // NOTE: This function is called both for recorded videos and imported videos
        
        let currentDate = NSDate()
        
        // This is a local URL to where the video is recorded or imported to
        let temporaryUrl = info[UIImagePickerControllerMediaURL]! as! NSURL
        
        // If the video was imported the asset url is defined
        if let assetUrl = info[UIImagePickerControllerReferenceURL] as? NSURL {
            
            // Imported video, try to get metadata from asset
            let library = ALAssetsLibrary()
            library.assetForURL(assetUrl, resultBlock: { asset in
                
                    let date = asset.valueForProperty(ALAssetPropertyDate) as? NSDate ?? currentDate
                    let location = asset.valueForProperty(ALAssetPropertyLocation) as? CLLocation
                    self.createVideoAndTitle(sourceVideoUrl: temporaryUrl, date: date, location: location)
                    
                }, failureBlock: { _ in
                    
                    self.createVideoAndTitle(sourceVideoUrl: temporaryUrl, date: currentDate, location: nil)
                }
            )
            
        } else {
            
            // Recorded video, get the metadata from current time and current location
            let location = LocationRetriever.instance.finishRetrievingLocation()
            self.createVideoAndTitle(sourceVideoUrl: temporaryUrl, date: currentDate, location: location)
        }
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        VideoRecorder.activeVideoRecorder = nil
    }
    
    private func createVideoTitle(date date: NSDate, location: CLLocation?, callback: String -> ()) {
        let dateText = NSDateFormatter.localizedStringFromDate(date, dateStyle: NSDateFormatterStyle.ShortStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
        
        if let location = location {
            LocationRetriever.instance.reverseGeocodeLocation(location) { placemark in
                if let street = placemark?.thoroughfare {
                    // Succesfully reverse geocoded the location: Use street and date
                    callback("\(street) \(dateText)")
                } else {
                    callback(dateText)
                }
            }
        }
        
        // No location fallback: Just use the date text
        callback(dateText)
    }

    private func createVideoAndTitle(sourceVideoUrl sourceVideoUrl: NSURL, date: NSDate, location: CLLocation?) {
    
        let videoLocation = location.map { Video.Location(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy) }
        
        createVideoTitle(date: date, location: location) { title in
            self.createVideo(sourceVideoUrl: sourceVideoUrl, title: title, location: videoLocation)
        }
    }
    
    private func createVideo(sourceVideoUrl sourceVideoUrl: NSURL, title: String, location: Video.Location?) {
        
        // Generate an unique ID for the video
        let id = NSUUID()
        let user = videoRepository.user
        
        do {
            // Store the video and thumbnail data under virtual iosdocuments:// URLs, these can be resolved with .realUrl
            let videoUrl = try NSURLComponents(string: "iosdocuments://videos/\(id.lowerUUIDString).mp4").unwrap().URL.unwrap()
            let thumbnailUrl = try NSURLComponents(string: "iosdocuments://thumbnails/\(id.lowerUUIDString).jpg").unwrap().URL.unwrap()
            
            // Create the directories if they don't exist
            try NSURL(string: "iosdcouments://videos/").unwrap().realUrl.unwrap().createDirectoryIfUnexisting()
            try NSURL(string: "iosdcouments://thumbnails/").unwrap().realUrl.unwrap().createDirectoryIfUnexisting()
            
            // Resolve the real video and thumbnail URLs
            let realVideoUrl = try videoUrl.realUrl.unwrap()
            let realThumbnailUrl = try thumbnailUrl.realUrl.unwrap()
            
            let video = Video(id: id, title: title, videoUri: videoUrl, thumbnailUri: thumbnailUrl, deleteUrl: nil, location: location, author: user, isPublic: false)
            
            // Note: The video object is saved last so that if something fails before it it won't be stored
            try saveThumbnailFromVideo(sourceVideoUrl, outputUrl: realThumbnailUrl)
            try NSFileManager.defaultManager().moveItemAtURL(sourceVideoUrl, toURL: realVideoUrl)
            try videoRepository.saveVideo(video)
            
            self.callback(.Success(video))
        } catch {
            self.callback(.Error(error))
        }
    }
}
