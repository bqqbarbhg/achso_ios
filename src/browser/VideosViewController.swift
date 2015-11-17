import UIKit
import MobileCoreServices

class VideosViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    // Initialized in didFinishLaunch, do not use in init
    weak var categoriesViewController: CategoriesViewController!

    var collection: Collection?
    
    var itemSize: CGSize?
    
    // Used to pass the video URL from selection to the segue callback
    var chosenVideoUrl: NSURL?
    
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
            
        dismissViewControllerAnimated(true) {
            self.chosenVideoUrl = (info[UIImagePickerControllerMediaURL]! as! NSURL)
            self.performSegueWithIdentifier("showPlayer", sender: self)
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

            if let videoUrl = self.chosenVideoUrl {
                playerViewController.createVideo(videoUrl)
            }
        }
        
        let handlers = [
            "showPlayer": handleShowPlayer,
        ]
        
        guard let identifier = segue.identifier else { return }
        guard let handler = handlers[identifier] else { return }
        
        handler(segue.destinationViewController)
    }

}
