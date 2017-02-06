/*

`VideosViewController` is the right-hand side view of the browsing activity that contains the video thumbnail grid.

This is a complicated view and has a lot of logic.

It handles these:

- Delegating to different view controllers
- Displaying the video thumbnails using VideoCellView.swift
- Filtering the videos based on search query using Search.swift
- Changing the UI depending on the state (selecting or not)
- Creates the video objects from recorded videos

*/

import UIKit
import MobileCoreServices
import AssetsLibrary
import CoreLocation

enum PendingAction {
    case RecordVideo
    case ShowVideo(NSUUID)
}

class VideosViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate, VideoRepositoryListener {
    
    // MARK: - connections
    
    @IBOutlet var collectionView: UICollectionView!
    
    @IBOutlet var actionButton: UIBarButtonItem!
    @IBOutlet var cameraButton: UIBarButtonItem!
    @IBOutlet var selectButton: UIBarButtonItem!
    @IBOutlet var cancelSelectButton: UIBarButtonItem!
    
    @IBOutlet var searchBar: UISearchBar!
 
    @IBOutlet var toolbarSpace: UIBarButtonItem!
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var uploadButton: UIBarButtonItem!

    @IBOutlet weak var progressBar: UIProgressView!
    
    @IBOutlet var searchBarToParentConstraint: NSLayoutConstraint!
    
    @IBOutlet var generalEmptyView: UIView!
    @IBOutlet var loadingEmptyView: UIView!
    
    @IBOutlet var generalEmptyViewLabel: UILabel!

    var refreshControl: UIRefreshControl!
    weak var categoriesViewController: CategoriesViewController!
    
    // MARK: - state
    
    // Current selected collection, the identifier is persistent but the collection is reloaded as necessary.
    var collectionId: CollectionIdentifier = .AllVideos
    var collection: Collection?
    
    // If the repository updates while in select mode, apply the changes after the user stops selecting.
    var pendingCollectionUpdateAfterSelect: Collection? = nil
    
    // List of currently visible videos
    var filteredVideos: [VideoInfo] = []
    
    var selectedVideos: [NSUUID] = []
    
    // Used to pass the video from selection to the segue callback
    var chosenVideo: Video?
    
    // Search index used for filtering videos. It is built dynamically when the user starts typing.
    var searchIndex: SearchIndex?
    var isBuildingSearchIndex: Bool = false
    
    // Filters for the videos.
    var searchFilter: String?
    
    // Token for the task which has the control over the progress bar, the newest one is given the control of the bar.
    var currentProgressBarOwner: String?
    
    // Cached size of the thumbnail views.
    var itemSize: CGSize?
    
    // Pending action to be launched
    var pendingAction: PendingAction?
    
    // MARK: - Setup
    
    override func viewDidLoad() {
        refreshSelectedViewState(animated: false)
        
        // Add the refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "startRefresh:", forControlEvents: .ValueChanged)
        self.refreshControl = refreshControl
        self.collectionView.addSubview(refreshControl)
        
        // Setup delegates
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        
        self.searchBar.delegate = self
        
        // Clear the filter parameters
        self.resetFilter()
    }
    
    // Listen to the video repository events when visible
    override func viewWillAppear(animated: Bool) {
        videoRepository.addListener(self)
        self.splitViewControllerDidChangeDisplayMode()
    }
    override func viewWillDisappear(animated: Bool) {
        videoRepository.removeListener(self)
    }
    
    override func viewDidAppear(animated: Bool) {
        doPendingAction()
    }
    
    func doPendingAction() {
        if let action = self.pendingAction {
            self.pendingAction = nil
            
            switch action {
            case .RecordVideo:
                self.recordVideo()
                
            case .ShowVideo(let id):
                videoRepository.getVideo(id) { tryVideo in
                    switch tryVideo {
                    case .Success(let video):
                        self.showVideo(video)
                    
                    case .Error(let error):
                        let title = NSLocalizedString("error_on_video_play", comment: "Error title when the video fails to play")
                        self.showErrorModal(error, title: title) {
                            videoRepository.getVideo(id) { tryVideo in
                                if let video = tryVideo.success {
                                    self.showVideo(video)
                                }
                            }
                        }
                    }
                }
                break
            }
        }
    }
    
    // MARK: - Top progress bar
    
    // Begin a task showing in the progress bar, use the same identifier in all calls.
    func beginProgressBar(identifier: String) {
        guard let progressBar = self.progressBar else { return }
        
        self.currentProgressBarOwner = identifier
        progressBar.setProgress(0.0, animated: false)
        self.progressBar.alpha = 0.0
        self.progressBar.hidden = false
        UIView.transitionWithView(self.progressBar, duration: 0.2, options: .CurveEaseOut, animations: {
                self.progressBar.alpha = 1.0
            },
            completion: nil)
        
    }
    
    // Set the progress bar progress.
    func updateProgressBar(identifier: String, progress: Float) {
        if identifier != self.currentProgressBarOwner { return }
        self.progressBar?.setProgress(progress, animated: true)
    }
    
    // Clear the progress bar.
    func endProgressBar(identifier: String) {
        if identifier != self.currentProgressBarOwner { return }
        self.currentProgressBarOwner = nil
        
        UIView.transitionWithView(self.progressBar, duration: 0.2, options: .CurveEaseOut, animations: {
            self.progressBar.alpha = 0.0
            }, completion: { _ in
                self.progressBar.hidden = true
        })
    }
    
    func splitViewControllerDidChangeDisplayMode() {
        guard let splitViewController = self.splitViewController else { return }
        
        self.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        self.navigationItem.leftItemsSupplementBackButton = true
    }
    
    func showCollection(collectionId: CollectionIdentifier) {
        self.collectionId = collectionId
        self.collection = videoRepository.retrieveCollectionByIdentifier(collectionId)
        self.searchIndex = nil
        self.resetFilter()
        if let collection = self.collection {
            updateCollection(collection)
        }
    }
    
    // MARK: - VideoRepositoryListener
    
    func videoRepositoryUpdateStart() {
        self.beginProgressBar("repository_update")
    }
    
    func videoRepositoryUpdateProgress(done: Int, total: Int) {

        if total <= 0 { return }
        self.updateProgressBar("repository_update", progress: Float(done) / Float(total))
        
        // HACKish: Force to update UI
        NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate())
    }
    
    func videoRepositoryUpdated() {

        self.collection = videoRepository.retrieveCollectionByIdentifier(self.collectionId)
        if let collection = self.collection {
            if !self.collectionView.allowsMultipleSelection {
                updateCollection(collection)
            } else {
                self.pendingCollectionUpdateAfterSelect = collection
            }
        }
        
        self.refreshControl.endRefreshing()
        self.endProgressBar("repository_update")
    }
    
    // MARK: - Collections and video filtering
    
    // Replace the current set of videos with `collection`
    func updateCollection(collection: Collection) {
        self.title = collection.title
        self.collection = collection
        
        // Invalidate the search index (will be rebuilt if needed)
        self.searchIndex = nil
        self.filterCollection()
    }

    // Produce and show `self.filteredVideos` which contains videos from the current collection matching the filter settings.
    func filterCollection() {
        guard let collection = self.collection else { return }
        var videos = collection.videos
        
        // Search filter: Allow only videos containing keywords
        if let searchFilter = self.searchFilter where !searchFilter.isEmpty {
            
            if let searchIndex = self.searchIndex {
                
                // If the search index exists query it and sort the results by score.
                let results = searchIndex.search(searchFilter)
                let uuids = results.sort({ $0.score > $1.score }).flatMap({ $0.object.tag as? NSUUID })
                
                // Map the IDs to videos
                let oldVideos = videos
                videos = uuids.flatMap { uuid in oldVideos.find { $0.id == uuid }  }
                
            } else {
                // The search index does not exist: Create one and filter when done.
                // This will re-call to filterContent()
                self.buildSearchIndex()
                
                // Return no results meanwhile.
                videos = []
            }
        }
        
        self.filteredVideos = videos
        self.updateEmptyPlaceholder()
        self.collectionView.reloadData()
    }
    
    func appendNewVideosToFiltered(videos: [Video]) {
        for video in videos {
            let videoinfo = VideoInfo(video: video)
        
           if !self.filteredVideos.contains(videoinfo) {
                filteredVideos.append(videoinfo)
            }
        }
    }
    
    func addOnlineVideoSearchResults(videos: [Video]) {
        appendNewVideosToFiltered(videos)
        self.collectionView.reloadData()
    }
    
    // Create a search index that can map keywords to videos.
    func buildSearchIndex() {
        
        // Only build it one time.
        if self.isBuildingSearchIndex { return }
        self.isBuildingSearchIndex = true
        
        self.updateEmptyPlaceholder()
        
        self.beginProgressBar("search_index")
        
        // Build in background thread.
        let videoInfos = collection?.videos ?? []
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let appDelegate = AppDelegate.instance
            let searchIndex = SearchIndex()
            
            // Add all the videos to the index.
            for (num, videoInfo) in videoInfos.enumerate() {
                
                if let video = (try? appDelegate.getVideo(videoInfo.id))?.flatMap({ $0 }) {
                    searchIndex.add(video.toSearchObject())
                }
                
                // Broadcast update notifications every now and then.
                if num % 10 == 0 {
                    dispatch_async(dispatch_get_main_queue()) {
                        let progress = Float(num) / Float(videoInfos.count)
                        self.updateProgressBar("search_index", progress: progress)
                    }
                }
            }
            
            // Finish it on the main thread.
            dispatch_async(dispatch_get_main_queue()) {
                self.endProgressBar("search_index")
                self.searchIndex = searchIndex
                self.isBuildingSearchIndex = false
                self.filterCollection()
            }
        }
    }
    
    // Resets the filter options (search query)
    func resetFilter() {
        self.searchFilter = nil
        self.searchBar?.text = nil
    }
    
    func startRefresh(sender: UIRefreshControl) {
        if !videoRepository.refreshOnline() {
            self.refreshControl.endRefreshing()
            showErrorModal(UserError.notSignedIn, title: NSLocalizedString("error_on_refresh",
                comment: "Error title when refreshing failed"))
        }
        self.updateEmptyPlaceholder()
    }
    
    @IBAction func genreButtonPressed(sender: UIButton) {
    }
    
    // MARK: - Search bar
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        
        // The user is probably going to search after focusing the search bar, start building the index already.
        if self.searchIndex == nil {
            self.buildSearchIndex()
        }
        
        searchBar.setShowsCancelButton(true, animated: true)
        
        self.refreshSearchBarViewState(animated: true)
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        videoRepository.searchVideosByOnlineQuery(self.searchFilter!) { result in
            if !result.isEmpty {
                self.showErrorModal(UserError.searchVideosFailed, title: NSLocalizedString("error_failed_to_search",
                    comment: "Error title when searching for online videos failed"))
            }
        }
        
        searchBar.setShowsCancelButton(false, animated: true)
        
        self.refreshSearchBarViewState(animated: true)
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        
        if searchText.isEmpty && !searchBar.isFirstResponder() {
            // Hack: if the text is empty and the search bar is not the first responder the user tapped the clear button.
            // Dismiss the keyboard after the first responder has propagated to the search bar.
            self.performSelector("searchBarCancelButtonClicked:", withObject: searchBar, afterDelay: 0)
            return
        }

        self.searchFilter = searchText
        self.filterCollection()
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        // Searching is real time, just hide the keyboard.
        self.searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        self.searchFilter = nil
        self.searchBar.text = nil
        self.filterCollection()
        self.searchBar.resignFirstResponder()
        
        self.refreshSearchBarViewState(animated: true)
    }
    
    func refreshSearchBarViewState(animated animated: Bool) {
        self.searchBarToParentConstraint.active = true;
        
        if animated {
            UIView.animateWithDuration(0.2) {
                self.searchBar.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Collection view data source and layout
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch (section) {
        case 0: return self.filteredVideos.count
        default: return 0
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCell", forIndexPath: indexPath) as! VideoViewCell
        
        if let video = self.filteredVideos[safe: indexPath.item] {
            cell.update(video)
            cell.setSelectable(true)
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
        let spacing = 2

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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.refreshSearchBarViewState(animated: false)
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
    
    func visibleCellForId(id: NSUUID) -> VideoViewCell? {
        let visibleCells = self.collectionView?.visibleCells() ?? []
        
        let maybeIndex = visibleCells.indexOf() { cell in
            guard let cell = cell as? VideoViewCell else { return false }
            guard let videoInfo = cell.videoInfo else { return false }
            return videoInfo.id == id
        }

        return maybeIndex.flatMap { visibleCells[$0] as? VideoViewCell }
    }
    
    // Sets the correct empty placeholder for the collection if necessary
    func updateEmptyPlaceholder() {
        
        // Remove the old background view
        if let oldBackgroundView = self.collectionView.backgroundView {
            oldBackgroundView.removeFromSuperview()
            self.collectionView.backgroundView = nil
        }
        
        // No background view if there are videos
        if !filteredVideos.isEmpty { return }
        
        // Collection expected
        guard let collection = self.collection else { return }
        
        self.collectionView.backgroundView = {
        
            if self.isBuildingSearchIndex || videoRepository.isOnlineRefreshing {
                return self.loadingEmptyView
            }
            
            if collection.videos.isEmpty {
                // The collection itself is empty
                switch self.collectionId {
                case .AllVideos:
                    self.generalEmptyViewLabel.text = NSLocalizedString("empty_videos_all", comment: "Placeholder when there are no videos at all in the app.")
                    return self.generalEmptyView
                case .Group:
                    self.generalEmptyViewLabel.text = NSLocalizedString("empty_videos_group", comment: "Placeholder when the group does not contain any videos")
                    return self.generalEmptyView
                case .QrSearch:
                    self.generalEmptyViewLabel.text = NSLocalizedString("empty_videos_qr", comment: "Placeholder when a scanner QR code does not match any videos")
                    return self.generalEmptyView
                }
            } else {
                // The filters have hidden all the videos
                self.generalEmptyViewLabel.text = NSLocalizedString("empty_videos_filtered", comment: "Placeholder when a filter excludes all the videos")
                return self.generalEmptyView
            }
            
        }()
    }
    
    // MARK: - Video selection
    
    func showVideo(video: Video) {
        self.chosenVideo = video
        self.performSegueWithIdentifier("showPlayer", sender: self)
    }
    
    
    func isVideoAtPathSelected(path: NSIndexPath) -> Bool {
        let currentVideo = self.videoForIndexPath(path)
        return selectedVideos.contains({$0 == currentVideo?.id })
    }
    
    func selectVideoAtPath(path: NSIndexPath) {
        let currentVideo = self.videoForIndexPath(path)
        selectedVideos.append((currentVideo?.id)!)
        
        if selectedVideos.count > 0 && collectionView.allowsMultipleSelection == false {
            self.toggleSelectionMode(true)
        }
        
        refreshSelectedViewState(animated: true)
    }
    
    func deselectVideoAtPath(path: NSIndexPath)  {
        let currentVideo = self.videoForIndexPath(path)
        self.selectedVideos = selectedVideos.filter{ return $0 != currentVideo?.id }
        
        if selectedVideos.count == 0 {
            self.toggleSelectionMode(false)
        }
        
        refreshSelectedViewState(animated: true)
    }
    
    func toggleSelectionMode(isMultiple: Bool) {
        
        if isMultiple {
            guard let collectionView = self.collectionView else { return }
            
            if collectionView.allowsMultipleSelection {
                self.endSelectMode()
            } else {
                collectionView.allowsMultipleSelection = true
            }
            
            refreshSelectedViewState(animated: true)
        } else {
            endSelectMode()
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
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let previouslySelected = isVideoAtPathSelected(indexPath)
        
        if !previouslySelected {
            self.selectVideoAtPath(indexPath)
        } else {
            let video = self.videoForIndexPath(indexPath)
            self.selectedVideos = []
            self.showVideo(video!)
        }
        
        /*if collectionView.allowsMultipleSelection {
            refreshSelectedViewState(animated: true)
        } else {
            if let video = videoForIndexPath(indexPath) {
                self.showVideo(video)
            } else {
                collectionView.deselectItemAtIndexPath(indexPath, animated: true)
            }
        }*/
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        
        let previouslySelected = isVideoAtPathSelected(indexPath)
        
        if !previouslySelected {
            self.selectVideoAtPath(indexPath)
        } else {
            let video = self.videoForIndexPath(indexPath)
            self.selectedVideos = []
            self.showVideo(video!)
        }
        
        deselectVideoAtPath(indexPath)
        
        if collectionView.allowsMultipleSelection {
            refreshSelectedViewState(animated: true)
        }
    }
    
    func endSelectMode() {
        guard let collectionView = self.collectionView else { return }
        for indexPath in collectionView.indexPathsForSelectedItems() ?? [] {
            collectionView.deselectItemAtIndexPath(indexPath, animated: true)
            deselectVideoAtPath(indexPath)
        }

        collectionView.allowsMultipleSelection = false
        self.refreshSelectedViewState(animated: true)
        
        if let collection = self.pendingCollectionUpdateAfterSelect {
            self.updateCollection(collection)
            self.pendingCollectionUpdateAfterSelect = nil
        }
    }
    
    func refreshSelectedViewState(animated animated: Bool) {
        guard let collectionView = self.collectionView else { return }
        
        let selectable = collectionView.allowsMultipleSelection
        for cell in collectionView.visibleCells() {
            (cell as? VideoViewCell)?.setSelectable(selectable)
        }
        
        if collectionView.allowsMultipleSelection {
            let selectedCount = collectionView.indexPathsForSelectedItems()?.count ?? 0
            
            self.editButton.enabled = selectedCount > 0
            self.uploadButton.enabled = selectedCount > 0
            self.actionButton.enabled = selectedCount > 0

            let selectedVideos = getSelectedVideoInfos()
            if selectedVideos.isEmpty || selectedVideos.contains({ $0.isLocal }) {
                self.uploadButton.title = NSLocalizedString("upload_button_upload", comment: "Upload button text when it uploads videos")
            } else {
                self.uploadButton.title = NSLocalizedString("upload_button_share", comment: "Upload button text when it only shares previously uploaded videos")
            }
            
            self.searchBar.userInteractionEnabled = false
            self.searchBar.alpha = 0.6
            
            // self.navigationItem.setHidesBackButton(true, animated: animated)
            self.cameraButton.enabled = false
            
            let items = [self.cancelSelectButton!]
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            
            self.navigationItem.leftBarButtonItem = nil
            self.splitViewController?.presentsWithGesture = false
            self.navigationItem.hidesBackButton = true
            
            let toolbarItems = [self.actionButton!, self.toolbarSpace!, self.uploadButton!, self.editButton!]
            self.setToolbarItems(toolbarItems, animated: animated)
            
        } else {
            self.searchBar.userInteractionEnabled = true
            self.searchBar.alpha = 1.0
            
            self.navigationItem.setHidesBackButton(false, animated: animated)
            self.cameraButton.enabled = true
            
            let items = [self.selectButton!]
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            
            self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
            self.splitViewController?.presentsWithGesture = true
            self.navigationItem.hidesBackButton = false
            
            self.actionButton.enabled = true
            let toolbarItems = [self.actionButton!, self.toolbarSpace!, self.cameraButton!]
            self.setToolbarItems(toolbarItems, animated: animated)
        }
    }
    
    func getSelectedVideoInfos() -> [VideoInfo] {
        let indices = self.collectionView.indexPathsForSelectedItems() ?? []
        return indices.flatMap { self.filteredVideos[safe: $0.item] }
    }
    
    func loadSelectedVideos() -> [Video] {
        let indices = self.collectionView.indexPathsForSelectedItems() ?? []
        return indices.flatMap { self.videoForIndexPath($0) }
    }
    
    // MARK: - Toolbar actions
    
    func uploadVideo(atIndexPath indexPath: NSIndexPath, callback: Try<Video> -> ()) -> Bool {
        guard let collectionView = self.collectionView else { return false }
        guard let video = videoForIndexPath(indexPath) else { return false }
        
        if !video.videoUri.isLocal {
            return false
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
            case .Success: break
            case .Error(let error): self.showErrorModal(error, title: NSLocalizedString("error_on_upload",
                comment: "Error title when the upload failed"))
            }
            
            callback(tryVideo)
        })
        
        return true
    }
    
    @IBAction func uploadButtonPressed(sender: UIBarButtonItem) {
        guard let collectionView = self.collectionView else { return }
        
        if !collectionView.allowsMultipleSelection { return }
        
        let videos = getSelectedVideoInfos()
        
        func shareVideos() {
            let ids = videos.map { $0.id }
            if ids.isEmpty { return }
            
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
        
        let selectedIndices = collectionView.indexPathsForSelectedItems() ?? []
        
        // Make sure all videos are pending upload before the callback has a chance to run, so there needs to be one more callback, which is placed after all the videos have been queued for upload.
        // This also starts the sharing even if all the videos have been previously uploaded.
        var totalCount = 1
        var uploadedCount = 0
        
        func callback() {
            uploadedCount += 1
            if uploadedCount == totalCount {
                shareVideos()
            }
        }
        
        let errorTitle = NSLocalizedString("error_before_upload",
            comment: "Error title if something prevented the user from uploading")
        self.doAuthenticated(errorTitle: errorTitle) {
            for indexPath in selectedIndices {
                if self.uploadVideo(atIndexPath: indexPath, callback: { _ in callback() }) {
                    totalCount += 1
                }
            }
            
            callback()
        }
        
        self.endSelectMode()
    }
    
    @IBAction func editButtonPressed(sender: UIBarButtonItem) {
        
        let videos = loadSelectedVideos()
        
        let detailsNav = self.storyboard!.instantiateViewControllerWithIdentifier("VideoDetailsViewController") as! UINavigationController
        let detailsController = detailsNav.topViewController as! VideoDetailsViewController
        detailsController.initializeForm(videos[0])
        
        self.endSelectMode()
        
        self.presentViewController(detailsNav, animated: true, completion: nil)
    }
    
    // MARK: - Action buttons
    
    @IBAction func actionButtonPressed(sender: UIBarButtonItem) {
        let actionPicker = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        if let popover = actionPicker.popoverPresentationController {
            popover.barButtonItem = sender
        }

        if self.collectionView.allowsMultipleSelection {
            
            // Selected mode
            
            actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_tag_to_qr", comment: "Action for tagging video(s) to a QR code"),
                style: .Default, handler: self.actionTagToQrCode))
            
            actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_export", comment: "Action for exporting videos"),
                style: .Default, handler: self.showExportPrompt))
            
            actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_delete", comment: "Action for deleting video(s)"),
                style: .Destructive, handler: self.actionDelete))
            
        } else {
            
            // Normal mode
         
            actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_import_video", comment: "Action for import video"),
                style: .Default, handler: self.actionImportVideo))
            
            actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_search_qr", comment: "Action for search QR code"),
                style: .Default, handler: self.actionScanQR))
            
            switch self.collectionId {
            case .Group:
                actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_group_info", comment: "Action for group info"),
                    style: .Default, handler: self.actionManageGroup))
            default:
                break
            }
            
            if Session.user == nil {
                actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_sign_in", comment: "Action for sign in"),
                    style: .Default, handler: self.actionSignIn))
                
            } else {
                actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_sign_out", comment: "Action for sign out"),
                    style: .Destructive, handler: self.actionSignOut))
                
                actionPicker.addAction(UIAlertAction(title: "\((Session.user?.name)!) (\((Session.user?.email)!))",
                    style: .Default, handler: nil))
            }
            
        }
        
        actionPicker.addAction(UIAlertAction(title: NSLocalizedString("action_cancel", comment: "Action for cancel"),
                              style: .Cancel, handler: nil))
        
        self.presentViewController(actionPicker, animated: true, completion: nil)
        
    }
    
    func actionImportVideo(action: UIAlertAction) {
        VideoRecorder.importVideo(viewController: self, callback: videoRecorded)
    }
    
    func actionScanQR(action: UIAlertAction) {
        
        func showQrCodeCollection(code: String) {
            self.showCollection(.QrSearch(code))
        }
        
        let qrController = self.storyboard!.instantiateViewControllerWithIdentifier("QRScanViewController") as! QRScanViewController
        qrController.callback = showQrCodeCollection
        
        self.presentViewController(qrController, animated: true, completion: nil)
    }
    
    func actionManageGroup(action: UIAlertAction) {
        
        guard let groupId: String = {
            switch self.collectionId {
            case .Group(let id): return id
            default: return nil
            }
        }() else { return }

        do {
            let sharesNav = self.storyboard!.instantiateViewControllerWithIdentifier("SharesViewController") as! UINavigationController
            let sharesController = sharesNav.topViewController as! SharesViewController
            try sharesController.prepareForManageGroup(groupId)
            self.presentViewController(sharesNav, animated: true) {
            }
        } catch {
            self.showErrorModal(error, title: NSLocalizedString("error_on_manage_group", comment: "Error title when the group info could not be found"))
        }
    }
    
    func actionSignIn(action: UIAlertAction) {
        Session.authenticate(fromViewController: self) { result in
            if let error = result.error {
                self.showErrorModal(error, title: NSLocalizedString("error_on_sign_in",
                    comment: "Error title when trying to sign in"))
            } else {
                videoRepository.refreshOnline()
                self.updateEmptyPlaceholder()
            }
        }
    }
    
    func actionSignOut(action: UIAlertAction) {
        Session.signOut()
    }
    
    func actionTagToQrCode(action: UIAlertAction) {
        let videos = loadSelectedVideos()
        
        func tagQrCode(code: String) {
            let appDelegate = AppDelegate.instance
            for video in videos {
                video.tag = code
                do {
                    try appDelegate.saveVideo(video, saveToDisk: false)
                } catch { }
            }
            appDelegate.saveContext()
            videoRepository.refresh()
        }
        
        let qrController = self.storyboard!.instantiateViewControllerWithIdentifier("QRScanViewController") as! QRScanViewController
        qrController.callback = tagQrCode
        
        self.presentViewController(qrController, animated: true, completion: nil)
        self.endSelectMode()
    }
    
    func getSelectedRemoteVideos() -> [Video] {
        let videos = loadSelectedVideos()
        var videosToExport = [Video]()
        
        for video in videos {
            if video.thumbnailUri.isLocal == false {
               videosToExport.append(video)
            }
        }
        
        return videosToExport
    }
    
    func showExportPrompt(action: UIAlertAction) {
        
        let videos = getSelectedRemoteVideos()
        
        if !videos.isEmpty {
            let exportAlert = UIAlertController(title: String(format: NSLocalizedString("action_export_title", comment: "Action for exporting videos"), videos.count), message: NSLocalizedString("action_export_desc", comment: "Prompt for exporting videos"), preferredStyle: .Alert)
            
                exportAlert.addTextFieldWithConfigurationHandler({ (emailField) -> Void in
                    emailField.text = Session.user?.email
                })
            
            
                exportAlert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: {(action) -> Void in
            
                }))
            
                exportAlert.addAction(UIAlertAction(title: "OK", style: .Default, handler: {(action) -> Void in
                    let field = exportAlert.textFields![0] as UITextField
                    let email = field.text
                
                    if email != nil {
                        if email!.isValidEmail {
                            self.actionExport(email!, videosToExport: videos)
                        } else {
                            self.showErrorModal(UserError.malFormedEmailAddress, title: email!)
                        }
                    }
                }))
                self.presentViewController(exportAlert, animated: true, completion: nil)
        }
    }
    
    func actionExport(email: String, videosToExport: [Video]) {
        
        if !videosToExport.isEmpty {
            videoRepository.exportVideos(videosToExport, email: email, doneCallback: { tryMessage in
                switch tryMessage {
                case .Success(_): break
                case .Error(let error):
                    self.showErrorModal(error, title: NSLocalizedString("error_failed_to_export",
                    comment: "Error title when exporting videos failed for whatever reason"))
                }
            
            })
        }
        
        self.endSelectMode()
    }

    func actionDelete(action: UIAlertAction) {
        let videos = loadSelectedVideos()

        let fileManager = NSFileManager.defaultManager()
        let appDelegate = AppDelegate.instance
        
        var skipped = false
        
        func deleteVideos(action: UIAlertAction) {
            
            var remoteVideosToDelete = [Video]()
            
            for video in videos {

                if video.thumbnailUri.isLocal {
                    do {
                        try fileManager.removeItemAtURL(video.thumbnailUri.realUrl.unwrap())
                    } catch {
                    }
                    
                    do {
                        try fileManager.removeItemAtURL(video.videoUri.realUrl.unwrap())
                    } catch {
                    }
                } else {
                    remoteVideosToDelete.append(video)
                }
                
                do {
                    try appDelegate.deleteVideo(video.id, saveToDisk: false)
                } catch {
                }
            }
            
            appDelegate.saveContext()
            videoRepository.refresh()
            
            if !remoteVideosToDelete.isEmpty {
                videoRepository.deleteVideos(remoteVideosToDelete) { errors in
                    videoRepository.refreshOnline()
                    
                    if let error = errors.first {
                        self.showErrorModal(error, title: NSLocalizedString("error_on_video_delete", comment: "Error title when trying to delete video"))
                    }
                }
            }

            self.endSelectMode()
        }
        
        func cancelDelete(action: UIAlertAction) {
            self.endSelectMode()
        }
        
        let confirmDialog = UIAlertController(title: NSLocalizedString("delete_confirmation_title", comment: "Title for the delete confirmation box"), message: nil, preferredStyle: .Alert)
        
        confirmDialog.addAction(UIAlertAction(title: NSLocalizedString("delete_confirmation_delete", comment: "Button that confirms to delete videos"), style: .Destructive, handler: deleteVideos))
        confirmDialog.addAction(UIAlertAction(title: NSLocalizedString("delete_confirmation_cancel", comment: "Button that cancels video deletion"), style: .Cancel, handler: cancelDelete))
        
        self.presentViewController(confirmDialog, animated: true, completion: nil)
    }
    
    // MARK: - Video recording
    
    @IBAction func cameraButtonPressed(sender: UIBarButtonItem) {
        recordVideo()
    }
    
    func recordVideo() {
        VideoRecorder.recordVideo(viewController: self, callback: videoRecorded)
    }
    
    func videoRecorded(tryVideo: Try<Video>, type: VideoRecordType) {
        
        // Go to all videos and scroll to the top so the new video is shown
        videoRepository.refresh()
        self.showCollection(.AllVideos)
        self.collectionView.setContentOffset(CGPointZero, animated: false)

        func viewDismissed() {
            switch tryVideo {
            case .Error(let error):
                switch type {
                case .Record:
                    self.showErrorModal(error, title: NSLocalizedString("error_on_video_record", comment: "Error title when trying to record video"))
                case .Import:
                    self.showErrorModal(error, title: NSLocalizedString("error_on_video_import", comment: "Error title when trying to import video"))
                }
                
            case .Success(let video):
                self.saveVideoAndRefresh(video)
            }
        }
        
        if self.presentedViewController != nil {
            self.dismissViewControllerAnimated(true, completion: viewDismissed)
        } else {
            viewDismissed()
        }
    }
    
    func saveVideoAndRefresh(video: Video) {
        do {
            try videoRepository.saveVideo(video)
            videoRepository.refresh()
        } catch {
            self.showErrorModal(error, title: NSLocalizedString("error_on_video_save",
                comment: "Error title when trying to save video"))
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
                    videoRepository.refreshVideo(video, isView: true, callback: playerViewController.videoDidUpdate)
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
        Session.doAuthenticated() { result in
            if let error = result.error {
                self.showErrorModal(error, title: errorTitle)
            } else {
                callback()
            }
        }
    }
}
