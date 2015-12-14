import UIKit
import MobileCoreServices

class VideosViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, UIImagePickerControllerDelegate, VideoRepositoryListener {
    
    @IBOutlet var collectionView: UICollectionView!
    
    @IBOutlet var cameraButton: UIBarButtonItem!
    @IBOutlet var selectButton: UIBarButtonItem!
    @IBOutlet var cancelSelectButton: UIBarButtonItem!
    
    @IBOutlet var genreButton: UIButton!
    @IBOutlet var searchBar: UISearchBar!
    
    @IBOutlet var toolbarSpace: UIBarButtonItem!
    @IBOutlet var shareButton: UIBarButtonItem!
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var uploadButton: UIBarButtonItem!

    /*
    @IBOutlet var manageGroupButton: UIBarButtonItem!
    */

    var refreshControl: UIRefreshControl!
    
    // Initialized in didFinishLaunch, do not use in init
    weak var categoriesViewController: CategoriesViewController!

    var collectionIndex: Int?
    var collection: Collection?
    
    var filteredVideos: [VideoInfo] = []
    
    var itemSize: CGSize?
    
    // Used to pass the video from selection to the segue callback
    var chosenVideo: Video?
    
    // If the repository updates while in select mode, apply the changes after the user stops selecting.
    var pendingCollectionUpdateAfterSelect: Collection? = nil
    
    var genreFilter: String?
    
    override func viewDidLoad() {
        refreshSelectedViewState(animated: false)
        
        // Refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "startRefresh:", forControlEvents: .ValueChanged)
        self.refreshControl = refreshControl
        self.collectionView.addSubview(refreshControl)
        
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        
        self.resetFilter()
        
        // Long press recognizer
        // NOTE: Removed, maybe this was a bad idea...
        /*
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "longPress:")
        self.collectionView?.addGestureRecognizer(longPressRecognizer)
        */
    }
    
    override func viewWillAppear(animated: Bool) {
        videoRepository.addListener(self)
        self.splitViewControllerDidChangeDisplayMode()
    }
    
    override func viewWillDisappear(animated: Bool) {
        videoRepository.removeListener(self)
    }
    
    func resetFilter() {
        self.genreFilter = nil
        self.genreButton?.setTitle(NSLocalizedString("filter_any_genre", comment: "Any genre filter option"), forState: .Normal)
    }
    
    func splitViewControllerDidChangeDisplayMode() {
        guard let splitViewController = self.splitViewController else { return }
        
        // HACK: Add this back if split view is removed from tablet
        // self.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
    }
    
    func showCollection(collectionIndex: Int) {
        self.collectionIndex = collectionIndex
        self.collection = videoRepository.collections[safe: collectionIndex]
        self.resetFilter()
        if let collection = self.collection {
            updateCollection(collection)
        }
    }
    
    func videoRepositoryUpdated() {
        guard let collectionIndex = self.collectionIndex else { return }
        self.collection = videoRepository.collections[safe: collectionIndex]
        if let collection = self.collection {
            if !self.collectionView.allowsMultipleSelection {
                updateCollection(collection)
            } else {
                self.pendingCollectionUpdateAfterSelect = collection
            }
        }
        
        self.refreshControl.endRefreshing()
    }
    
    func updateCollection(collection: Collection) {
        self.title = collection.title
        self.collection = collection
        
        self.filterContent()
    }
    
    func filterContent() {
        guard let collection = self.collection else { return }
        var videos = collection.videos
        
        if let genreFilter = self.genreFilter {
            videos = videos.filter({ $0.genre == genreFilter })
        }
        
        self.filteredVideos = videos
        self.collectionView.reloadData()
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
            refreshSelectedViewState(animated: true)
        }
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch (section) {
        case 0:
            return self.filteredVideos.count
        default:
            return 0
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCell", forIndexPath: indexPath) as! VideoViewCell
        
        if let video = self.filteredVideos[safe: indexPath.item] {
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
        return 1
    }

    
    func calculateItemSize() -> CGSize? {
        let viewSize = self.view.bounds.size

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
            guard let videoInfo = self.filteredVideos[safe: indexPath.item] else { return nil }
            guard let video = try appDelegate.getVideo(videoInfo.id) else { return nil }
            return video
        } catch {
            return nil
        }
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if collectionView.allowsMultipleSelection {

            refreshSelectedViewState(animated: true)
            
        } else {
            
            if let video = videoForIndexPath(indexPath) {
                
                self.chosenVideo = video
                self.performSegueWithIdentifier("showPlayer", sender: self)
            } else {
                collectionView.deselectItemAtIndexPath(indexPath, animated: true)
            }
        }
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        if collectionView.allowsMultipleSelection {
            refreshSelectedViewState(animated: true)
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
        
        if collectionView.allowsMultipleSelection {
            self.endSelectMode()
        } else {
            collectionView.allowsMultipleSelection = true
        }
        
        refreshSelectedViewState(animated: true)
    }
    
    func endSelectMode() {
        self.deselectAllItems()
        collectionView.allowsMultipleSelection = false
        self.refreshSelectedViewState(animated: true)
        
        if let collection = self.pendingCollectionUpdateAfterSelect {
            self.updateCollection(collection)
            self.pendingCollectionUpdateAfterSelect = nil
        }
    }
    
    func refreshSelectedViewState(animated animated: Bool) {
        guard let collectionView = self.collectionView else { return }
        
        if collectionView.allowsMultipleSelection {
            let selectedCount = collectionView.indexPathsForSelectedItems()?.count ?? 0
            
            self.shareButton.enabled = selectedCount > 0
            self.editButton.enabled = selectedCount == 1
            self.uploadButton.enabled = selectedCount > 0

            self.genreButton.enabled = false
            self.searchBar.userInteractionEnabled = false
            self.searchBar.alpha = 0.6
            
            self.navigationItem.setHidesBackButton(true, animated: animated)
            self.cameraButton.enabled = false
            
            let items = [self.cancelSelectButton!]
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            
            self.categoriesViewController?.setEnabled(false)
            self.navigationController?.setToolbarHidden(false, animated: animated)
            
        } else {
            self.genreButton.enabled = true
            self.searchBar.userInteractionEnabled = true
            self.searchBar.alpha = 1.0
            
            self.navigationItem.setHidesBackButton(false, animated: animated)
            self.cameraButton.enabled = true
            
            let items = [self.cameraButton!, self.selectButton!]
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            
            self.categoriesViewController?.setEnabled(true)
            self.navigationController?.setToolbarHidden(true, animated: animated)
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
                
                self.endSelectMode()
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
        
        self.endSelectMode()
        
        self.presentViewController(detailsNav, animated: true, completion: nil)
    }
    
    
    @IBAction func shareButtonPressed(sender: UIBarButtonItem) {
        guard let collectionView = self.collectionView else { return }
        let indices = collectionView.indexPathsForSelectedItems() ?? []
        let videos = indices.flatMap { self.videoForIndexPath($0) }
        let ids = videos.map { $0.id }
        
        self.endSelectMode()
        
        if ids.count == 0 { return }
        
        do {
            let sharesNav = self.storyboard!.instantiateViewControllerWithIdentifier("SharesViewController") as! UINavigationController
            let sharesController = sharesNav.topViewController as! SharesViewController
            try sharesController.prepareForShareVideos(ids)
            self.presentViewController(sharesNav, animated: true) {
            }
        } catch {
            self.showErrorModal(error, title: NSLocalizedString("error_on_share", comment: "Error title when trying to share videos to groups was interrupted"))
        }
    }
    
    @IBAction func manageGroupButtonPressed(sender: UIBarButtonItem) {
        guard let group = self.collection?.extra as? Group else { return }
        do {
            
            let sharesNav = self.storyboard!.instantiateViewControllerWithIdentifier("SharesViewController") as! UINavigationController
            let sharesController = sharesNav.topViewController as! SharesViewController
            try sharesController.prepareForManageGroup(group.id)
            self.presentViewController(sharesNav, animated: true) {
            }
        } catch {
            self.showErrorModal(error, title: NSLocalizedString("error_on_share", comment: "Error title when trying to share videos to groups was interrupted"))
        }
    }
    
    @IBAction func genreButtonPressed(sender: UIButton) {
        
        func picked(genre: String?, title: String?) {
            self.genreButton.setTitle(title, forState: .Normal)
            self.genreFilter = genre
            self.filterContent()
        }

        let pickerTitle = NSLocalizedString("filter_genre_title", comment: "Title of the genre picker")
        let genrePicker = UIAlertController(title: pickerTitle, message: nil, preferredStyle: .ActionSheet)

        if let popover = genrePicker.popoverPresentationController {
            popover.sourceView = self.genreButton
            popover.sourceRect = CGRect(x: self.genreButton.bounds.midX, y: self.genreButton.bounds.maxY, width: 0.0, height: 0.0)
        }
        
        let button = UIAlertAction(title: NSLocalizedString("filter_any_genre", comment: "Any genre filter option"), style: .Default) { action in
            picked(nil, title: action.title)
        }
        genrePicker.addAction(button)
        
        // Todo: enum?
        let genres = ["good_work", "problem", "site_overview", "trick_of_trade"]
        for genre in genres {
            let button = UIAlertAction(title: NSLocalizedString(genre, comment: "Genre"), style: .Default) { action in
                picked(genre, title: action.title)
            }
            genrePicker.addAction(button)
        }
        
        self.presentViewController(genrePicker, animated: true, completion: nil)
    }
    
    @IBAction func cameraButtonPressed(sender: UIBarButtonItem) {
        
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
                        let rect = CGRect(x: cell.genreLabel.bounds.minX + 10.0, y: cell.genreLabel.bounds.maxY, width: 0, height: 0)
                        popover.permittedArrowDirections = UIPopoverArrowDirection.Up
                        popover.sourceRect = rect
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
