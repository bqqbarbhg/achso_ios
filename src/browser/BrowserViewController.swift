import UIKit

class BrowserViewController: UISplitViewController, UISplitViewControllerDelegate {
    
    var videosViewController: VideosViewController!
    
    override func viewDidLoad() {
        
        // The categories view does not need to be so wide (320 is the default)
        self.maximumPrimaryColumnWidth = 260
        self.delegate = self
    }

    func splitViewController(svc: UISplitViewController, willChangeToDisplayMode displayMode: UISplitViewControllerDisplayMode) {
        self.videosViewController.splitViewControllerDidChangeDisplayMode()
    }
}

