import UIKit
import MobileCoreServices

class VideosViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet var toolbarSpace: UIBarButtonItem!
    @IBOutlet var uploadButton: UIBarButtonItem!
    @IBOutlet var selectButton: UIBarButtonItem!
    
    // Initialized in didFinishLaunch, do not use in init
    weak var categoriesViewController: CategoriesViewController!

    var collection: Collection?
    
    var itemSize: CGSize?
    
   
    // Used to pass the video from selection to the segue callback
    var chosenVideo: Video?
    
    override func viewDidLoad() {
        refreshToolbarView(animated: false)
    }
    
    func showCollection(collection: Collection) {
        self.title = collection.title
        self.collection = collection
        
        self.collectionView?.reloadData()
    }
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch (section) {
        case 0:
            return self.collection?.videos.count ?? 0
        default:
            return 0
        }
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCell", forIndexPath: indexPath) as! VideoViewCell
        
        if let video = collection?.videos[safe: indexPath.item] {
            cell.update(video)
        }
        
        return cell
    }
    
    func getNumberOfItemsPerRow(forWidth width: CGFloat) -> Int {
        
        struct LayoutBreak {
            let minimumWidth: CGFloat
            let numberOfItemsPerRow: Int
            
            init(minimumWidth: CGFloat, numberOfItemsPerRow: Int) {
                self.minimumWidth = minimumWidth
                self.numberOfItemsPerRow = numberOfItemsPerRow
            }
        }
        
        let layoutBreaks = [
            LayoutBreak(minimumWidth: 700.0, numberOfItemsPerRow: 3),
            LayoutBreak(minimumWidth: 450.0, numberOfItemsPerRow: 2),
        ]
        
        // Try to find a break that is smaller than the current width
        for layoutBreak in layoutBreaks {
            if width > layoutBreak.minimumWidth {
                return layoutBreak.numberOfItemsPerRow
            }
        }
        
        // Default single column
        return 1;
    }

    
    func calculateItemSize() -> CGSize? {
        guard let viewSize = self.collectionView?.bounds.size else {
            return nil
        }

        // This should match the spacing configured in the storyboard
        let spacing = 5

        let viewSpaceWidth = viewSize.width - CGFloat(spacing * 2)
        
        let numberOfItemsPerRow = getNumberOfItemsPerRow(forWidth: viewSpaceWidth)
        let width = viewSpaceWidth / CGFloat(numberOfItemsPerRow)
        
        let aspectRatio = 4.0 / 3.0
        let height = width / CGFloat(aspectRatio)
        
        let halfSpacing = CGFloat(spacing) / 2.0
        return CGSize(width: width - halfSpacing, height: height - halfSpacing)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let newItemSize = calculateItemSize()
        if self.itemSize != newItemSize {
            self.itemSize = newItemSize
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        if self.itemSize == nil {
            self.itemSize = calculateItemSize()
        }
        
        if let itemSize = self.itemSize {
            return itemSize
        } else {
            return CGSize(width: 400, height: 300)
        }
    }
    
    func videoForIndexPath(indexPath: NSIndexPath) -> Video? {
        do {
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            guard let videoInfo = self.collection?.videos[safe: indexPath.item] else { return nil }
            guard let video = try appDelegate.getVideo(videoInfo.id) else { return nil }
            return video
        } catch {
            showErrorModal(error)
            return nil
        }
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if collectionView.allowsMultipleSelection {

            refreshToolbarView(animated: true)
            
        } else {
            
            if let video = videoForIndexPath(indexPath) {
                self.chosenVideo = video
                self.performSegueWithIdentifier("showPlayer", sender: self)
            } else {
                collectionView.deselectItemAtIndexPath(indexPath, animated: true)
            }
        }
    }
    
    override func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        if collectionView.allowsMultipleSelection {
            refreshToolbarView(animated: true)
        }
    }
    
    func deselectAllItems() {
        guard let collectionView = self.collectionView else { return }
        for indexPath in collectionView.indexPathsForSelectedItems() ?? [] {
            collectionView.deselectItemAtIndexPath(indexPath, animated: true)
        }
    }
    
    @IBAction func selectButtonPressed(sender: UIBarButtonItem) {
        guard let collectionView = self.collectionView else { return }
        
        collectionView.allowsMultipleSelection = !collectionView.allowsMultipleSelection
        self.deselectAllItems()
        
        refreshToolbarView(animated: true)
    }
    
    func refreshToolbarView(animated animated: Bool) {
        guard let collectionView = self.collectionView else { return }
        
        var newItems: [UIBarButtonItem] = []
        
        newItems.append(self.toolbarSpace)
        
        if collectionView.allowsMultipleSelection {
            let selectedCount = collectionView.indexPathsForSelectedItems()?.count ?? 0
            
            self.uploadButton.enabled = selectedCount > 0
            newItems.append(self.uploadButton)
        }
        
        newItems.append(selectButton)
        
        let equal = self.toolbarItems.map { oldItems -> Bool in
            if oldItems.count != newItems.count { return false }
            for pair in zip(oldItems, newItems) {
                if pair.0 !== pair.1 { return false }
            }
            return true
        } ?? false
        
        if !equal {
            self.setToolbarItems(newItems, animated: true)
        }
    }
    
    func uploadVideo(atIndexPath indexPath: NSIndexPath) {
        guard let collectionView = self.collectionView else { return }
        guard let video = videoForIndexPath(indexPath) else { return }
        
        videoRepository.uploadVideo(video, progressCallback: { value, animated in
            if let cell = collectionView.cellForItemAtIndexPath(indexPath) as? VideoViewCell {
                cell.setProgress(value, animated: animated)
            }
        }, doneCallback: { video in
            if let cell = collectionView.cellForItemAtIndexPath(indexPath) as? VideoViewCell {
                cell.clearProgress()
            }
        })
    }
    
    @IBAction func uploadButtonPressed(sender: UIBarButtonItem) {
        guard let collectionView = self.collectionView else { return }
        
        if collectionView.allowsMultipleSelection {
            let selectedIndices = collectionView.indexPathsForSelectedItems() ?? []
            self.authenticate() {
                for indexPath in selectedIndices {
                    self.uploadVideo(atIndexPath: indexPath)
                }
                
                self.deselectAllItems()
                collectionView.allowsMultipleSelection = false
                self.refreshToolbarView(animated: true)
            }
        }
    }

    @IBAction func cameraButton(sender: UIBarButtonItem) {
        
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
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let temporaryUrl = (info[UIImagePickerControllerMediaURL]! as! NSURL)
        let id = NSUUID()
        
        let title = NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: NSDateFormatterStyle.ShortStyle, timeStyle: NSDateFormatterStyle.FullStyle)
        
        let fileManager = NSFileManager.defaultManager()
        guard let documentsUrl = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[safe: 0] else {
            return
        }

        let videosUrl = documentsUrl.URLByAppendingPathComponent("videos", isDirectory: true)
        let thumbnailsUrl = documentsUrl.URLByAppendingPathComponent("thumbnails", isDirectory: true)
        
        do {
            try videosUrl.createDirectoryIfUnexisting()
            try thumbnailsUrl.createDirectoryIfUnexisting()
        } catch {
            return
        }
        
        let videoUrl = videosUrl.URLByAppendingPathComponent("\(id.lowerUUIDString).mp4")
        let thumbnailUrl = thumbnailsUrl.URLByAppendingPathComponent("\(id.lowerUUIDString).jpg")
        
        let video = Video(id: id, title: title, videoUri: videoUrl, thumbnailUri: thumbnailUrl)
        
        func saveUrl(callback: ErrorType? -> ()) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let returnValue: ErrorType? = {
                    do {
                        try fileManager.copyItemAtURL(temporaryUrl, toURL: videoUrl)
                        return nil
                    } catch {
                        return error
                    }
                }()
                
                dispatch_async(dispatch_get_main_queue()) {
                    callback(returnValue)
                }
            }
        }
        
        func generateThumbnailAndDismissView(callback: ErrorType? -> ()) {
            
            do {
                let filename = "\(id.lowerUUIDString).jpg"
                video.thumbnailUri = try saveThumbnailFromVideo(temporaryUrl, filename: filename)
                
                try AppDelegate.instance.saveVideo(video)
                
                dismissViewControllerAnimated(true) {
                    callback(nil)
                }
            } catch {
                callback(error)
            }
        }
        
        parallelAsync(saveUrl, generateThumbnailAndDismissView, success: {
            self.chosenVideo = video
            self.performSegueWithIdentifier("showPlayer", sender: self)
        }, errors: { errors in
            
        })

    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        func handleShowPlayer(viewController: UIViewController) {
            guard let navigationController = viewController as? UINavigationController else {
                return
            }
            
            guard let playerViewController = navigationController.topViewController as? PlayerViewController else {
                return
            }

            if let video = self.chosenVideo {
                playerViewController.setVideo(video)
            }
        }
        
        let handlers = [
            "showPlayer": handleShowPlayer,
        ]
        
        guard let identifier = segue.identifier else { return }
        guard let handler = handlers[identifier] else { return }
        
        handler(segue.destinationViewController)
    }

    @IBAction func loginButtonPressed(sender: UIBarButtonItem) {
        self.authenticate() {
        }
    }
    
    func showErrorModal(error: ErrorType) {
        var errorTitle = "Error"
        var errorMessage = "An unknown error happened"

        if let userError = error as? PrintableError {
            errorMessage = userError.localizedErrorDescription
        }
        
        let alertController = UIAlertController(title: errorTitle, message: errorMessage, preferredStyle: .Alert)
        
        let okAction = UIAlertAction(title: "OK", style: .Default, handler: { action in
            alertController.dismissViewControllerAnimated(true, completion: nil)
        })
        alertController.addAction(okAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func tempSetup() {
        guard let http = HTTPClient.http else { return }
        
        if let achrailsUrl = Secrets.getUrl("ACHRAILS_URL") {
            let achrails = AchRails(http: http, endpoint: achrailsUrl)
            videoRepository.achRails = achrails
        }
        
        if let achminupUrl = Secrets.getUrl("ACHMINUP_URL") {
            let achminup = AchMinUpUploader(endpoint: achminupUrl)
            videoRepository.videoUploaders = [achminup]
            videoRepository.thumbnailUploaders = [achminup]
        }
        
        videoRepository.refresh()
    }
    
    func authenticate(callback: () -> ()) {
        HTTPClient.doAuthenticated(fromViewController: self) { result in
            switch result {
            case .OldSession:
                callback()
            case .NewSession:
                self.tempSetup()
                callback()
            case .Unauthenticated: break
                // TODO: Something
            case .Error(let error):
                self.showErrorModal(error)
            }
        }
    }
}
