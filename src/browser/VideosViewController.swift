import UIKit
import MobileCoreServices

class VideosViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, UIImagePickerControllerDelegate, VideoRepositoryListener {
    
    @IBOutlet var toolbarSpace: UIBarButtonItem!
    @IBOutlet var shareButton: UIBarButtonItem!
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var uploadButton: UIBarButtonItem!
    @IBOutlet var selectButton: UIBarButtonItem!
    
    var refreshControl: UIRefreshControl!
    
    // Initialized in didFinishLaunch, do not use in init
    weak var categoriesViewController: CategoriesViewController!

    var collectionIndex: Int?
    var collection: Collection?
    
    var itemSize: CGSize?
    
    // Used to pass the video from selection to the segue callback
    var chosenVideo: Video?
    
    override func viewDidLoad() {
        refreshToolbarView(animated: false)
        
        // Refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "startRefresh:", forControlEvents: .ValueChanged)
        self.collectionView?.addSubview(refreshControl)
        
        self.refreshControl = refreshControl
        
        // Long press recognizer
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "longPress:")
        self.collectionView?.addGestureRecognizer(longPressRecognizer)
    }
    
    override func viewWillAppear(animated: Bool) {
        videoRepository.addListener(self)
        self.splitViewControllerDidChangeDisplayMode()
    }
    
    override func viewWillDisappear(animated: Bool) {
        videoRepository.removeListener(self)
    }
    
    func splitViewControllerDidChangeDisplayMode() {
        guard let splitViewController = self.splitViewController else { return }
        
        // HACK: Add this back if split view is removed from tablet
        // self.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
    }
    
    func showCollection(collectionIndex: Int) {
        self.collectionIndex = collectionIndex
        self.collection = videoRepository.collections[safe: collectionIndex]
        if let collection = self.collection {
            updateCollection(collection)
        }
    }
    
    func videoRepositoryUpdated() {
        guard let collectionIndex = self.collectionIndex else { return }
        self.collection = videoRepository.collections[safe: collectionIndex]
        if let collection = self.collection {
            updateCollection(collection)
        }
        
        self.refreshControl.endRefreshing()
    }
    
    func updateCollection(collection: Collection) {
        self.title = collection.title
        self.collection = collection
        
        self.collectionView?.reloadData()
    }
    
    func startRefresh(sender: UIRefreshControl) {
        if !videoRepository.refreshOnline() {
            self.refreshControl.endRefreshing()
            showErrorModal(UserError.notSignedIn, title: NSLocalizedString("error_on_refresh",
                comment: "Error title when refreshing failed"))
        }
    }
    
    func longPress(sender: UILongPressGestureRecognizer) {
        guard let collectionView = self.collectionView else { return }
        if sender.state != .Began { return }
        
        let point = sender.locationInView(collectionView)
        if let indexPath = collectionView.indexPathForItemAtPoint(point) {
            collectionView.allowsMultipleSelection = true
            collectionView.selectItemAtIndexPath(indexPath, animated: false, scrollPosition: .None)
            refreshToolbarView(animated: true)
        }
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
            
            self.shareButton.enabled = selectedCount > 0
            self.editButton.enabled = selectedCount == 1
            self.uploadButton.enabled = selectedCount > 0
            
            newItems.append(self.shareButton)
            newItems.append(self.editButton)
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
            self.setToolbarItems(newItems, animated: animated)
        }
    }
    
    func uploadVideo(atIndexPath indexPath: NSIndexPath) {
        guard let collectionView = self.collectionView else { return }
        guard let video = videoForIndexPath(indexPath) else { return }
        
        if !video.videoUri.isLocal {
            return
        }
        
        videoRepository.uploadVideo(video, progressCallback: { value, animated in
            if let cell = collectionView.cellForItemAtIndexPath(indexPath) as? VideoViewCell {
                cell.setProgress(value, animated: animated)
            }
        }, doneCallback: { tryVideo in
            if let cell = collectionView.cellForItemAtIndexPath(indexPath) as? VideoViewCell {
                cell.clearProgress()
            }
            
            switch tryVideo {
            case .Success(let video): break
            case .Error(let error): self.showErrorModal(error, title: NSLocalizedString("error_on_upload",
                comment: "Error title when the upload failed"))
            }
        })
    }
    
    @IBAction func uploadButtonPressed(sender: UIBarButtonItem) {
        guard let collectionView = self.collectionView else { return }
        
        if collectionView.allowsMultipleSelection {
            let selectedIndices = collectionView.indexPathsForSelectedItems() ?? []
            
            let errorTitle = NSLocalizedString("error_before_upload",
                comment: "Error title if something prevented the user from uploading")
            self.doAuthenticated(errorTitle: errorTitle) {
                for indexPath in selectedIndices {
                    self.uploadVideo(atIndexPath: indexPath)
                }
                
                self.deselectAllItems()
                collectionView.allowsMultipleSelection = false
                self.refreshToolbarView(animated: true)
            }
        }
    }
    
    @IBAction func editButtonPressed(sender: UIBarButtonItem) {
        guard let collectionView = self.collectionView else { return }
        guard let selectedList = collectionView.indexPathsForSelectedItems() else { return }
        guard let selected = selectedList.first else { return }
        guard let video = videoForIndexPath(selected) else { return }
        
        let detailsNav = self.storyboard!.instantiateViewControllerWithIdentifier("VideoDetailsViewController") as! UINavigationController
        let detailsController = detailsNav.topViewController as! VideoDetailsViewController
        detailsController.initializeForm(video)
        
        self.deselectAllItems()
        collectionView.allowsMultipleSelection = false
        self.refreshToolbarView(animated: true)
        
        self.presentViewController(detailsNav, animated: true, completion: nil)
    }
    
    
    @IBAction func shareButtonPressed(sender: UIBarButtonItem) {
        guard let collectionView = self.collectionView else { return }
        let indices = collectionView.indexPathsForSelectedItems() ?? []
        let videos = indices.flatMap { self.videoForIndexPath($0) }
        let ids = videos.map { $0.id }
        
        let sharesNav = self.storyboard!.instantiateViewControllerWithIdentifier("SharesViewController") as! UINavigationController
        let sharesController = sharesNav.topViewController as! SharesViewController
        sharesController.prepareForShareVideos(ids)
        self.presentViewController(sharesNav, animated: true) {
        }
    }
    
    @IBAction func cameraButton(sender: UIBarButtonItem) {
        
        LocationRetriever.instance.startRetrievingLocation(self.startRecordingVideo)
        
    }
    
    func startRecordingVideo() {
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
        
        let temporaryUrl = info[UIImagePickerControllerMediaURL]! as! NSURL
        let date = NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: NSDateFormatterStyle.ShortStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
        

        
        if let location = LocationRetriever.instance.finishRetrievingLocation() {
            LocationRetriever.instance.reverseGeocodeLocation(location) { street in
                if let street = street {
                    let videoLocation = Video.Location(latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude, accuracy: location.horizontalAccuracy)
                    
                    self.createVideo(sourceVideoUrl: temporaryUrl, title: "\(street) \(date)", location: videoLocation)
                } else {
                    self.createVideo(sourceVideoUrl: temporaryUrl, title: date, location: nil)
                }
            }
        } else {
            self.createVideo(sourceVideoUrl: temporaryUrl, title: date, location: nil)
        }

    }

    func createVideo(sourceVideoUrl sourceVideoUrl: NSURL, title: String, location: Video.Location?) {
        let id = NSUUID()
        
        let videoUrl = NSURLComponents(string: "iosdocuments://videos/\(id.lowerUUIDString).mp4")!.URL!
        let thumbnailUrl = NSURLComponents(string: "iosdocuments://thumbnails/\(id.lowerUUIDString).jpg")!.URL!
        
        let fileManager = NSFileManager.defaultManager()
        guard let documentsUrl = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[safe: 0] else {
            return
        }
        
        let videosUrl = documentsUrl.URLByAppendingPathComponent("videos", isDirectory: true)
        let thumbnailsUrl = documentsUrl.URLByAppendingPathComponent("thumbnails", isDirectory: true)
        
        do {
            try videosUrl.createDirectoryIfUnexisting()
            try thumbnailsUrl.createDirectoryIfUnexisting()
            
            let video = Video(id: id, title: title, videoUri: videoUrl, thumbnailUri: thumbnailUrl, location: location)
            
            let realVideoUrl = try videoUrl.realUrl.unwrap()
            let realThumbnailUrl = try thumbnailUrl.realUrl.unwrap()
            
            try saveThumbnailFromVideo(sourceVideoUrl, outputUrl: realThumbnailUrl)
            try fileManager.moveItemAtURL(sourceVideoUrl, toURL: realVideoUrl)
            try videoRepository.saveVideo(video)
            
            dismissViewControllerAnimated(true) {
                
                func picked(genre: String) {
                    video.genre = genre
                    do {
                        try videoRepository.saveVideo(video)
                        self.chosenVideo = video
                        self.performSegueWithIdentifier("showPlayer", sender: self)
                    } catch {
                        self.showErrorModal(error, title: NSLocalizedString("error_on_video_save",
                            comment: "Error title when trying to save video"))
                    }
                }
                
                let pickerTitle = NSLocalizedString("choose_genre_title", comment: "Title of the genre picker")
                let genrePicker = UIAlertController(title: pickerTitle, message: nil, preferredStyle: .ActionSheet)
                let visibleCells = self.collectionView?.visibleCells() ?? []
                let maybeIndex = visibleCells.indexOf() { cell in
                    guard let cell = cell as? VideoViewCell else { return false }
                    guard let videoInfo = cell.videoInfo else { return false }
                    return videoInfo.id == id
                }
                
                if let popover = genrePicker.popoverPresentationController {
                    if let index = maybeIndex {
                        let cell = visibleCells[index] as! VideoViewCell
                        popover.sourceView = cell.genreLabel
                        let rect = cell.genreLabel.bounds.divide(1.0, fromEdge: CGRectEdge.MaxYEdge).slice
                        let leftRect = rect.divide(20.0, fromEdge: CGRectEdge.MinXEdge).slice
                        popover.permittedArrowDirections = UIPopoverArrowDirection.Up
                        popover.sourceRect = leftRect
                    } else {
                        popover.sourceView = self.view
                    }
                }
                
                // Todo: enum?
                let genres = ["good_work", "problem", "site_overview", "trick_of_trade"]
                for genre in genres {
                    let button = UIAlertAction(title: NSLocalizedString(genre, comment: "Genre"), style: .Default) { _ in
                        picked(genre)
                    }
                    genrePicker.addAction(button)
                }
                
                self.presentViewController(genrePicker, animated: true, completion: nil)
                
            }
            
        } catch {
            dismissViewControllerAnimated(true) {
                self.showErrorModal(error, title: NSLocalizedString("error_on_video_save",
                    comment: "Error title when trying to save video"))
            }
        }
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
                do {
                    try playerViewController.setVideo(video)
                } catch {
                    // TODO: Cancel segue
                }
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
        HTTPClient.authenticate(fromViewController: self) { result in
            if let error = result.error {
                self.showErrorModal(error, title: NSLocalizedString("error_on_sign_in",
                    comment: "Error title when trying to sign in"))
            } else {
                videoRepository.refreshOnline()
            }
        }
    }
    
    func showErrorModal(error: ErrorType, title: String) {
        var errorMessage = NSLocalizedString("error_unknown",
            comment: "Error title when some unknown error happened")

        let errorDismissButton = NSLocalizedString("error_dismiss",
            comment: "Button title for dismissing the error")
        
        if let printableError = error as? PrintableError {
            errorMessage = printableError.localizedErrorDescription
        }
        
        let alertController = UIAlertController(title: title, message: errorMessage, preferredStyle: .Alert)
        
        let dismissAction = UIAlertAction(title: errorDismissButton, style: .Default, handler: { action in
            alertController.dismissViewControllerAnimated(true, completion: nil)
        })
        
        alertController.addAction(dismissAction)
        
        if let userError = error as? UserError, fix = userError.fix {
            let fixAction = UIAlertAction(title: fix.title, style: .Default, handler: { action in
                fix.action(self)
            })
            alertController.addAction(fixAction)
        }
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func doAuthenticated(errorTitle errorTitle: String, callback: () -> ()) {
        HTTPClient.doAuthenticated() { result in
            if let error = result.error {
                self.showErrorModal(error, title: errorTitle)
            } else {
                callback()
            }
        }
    }
}
