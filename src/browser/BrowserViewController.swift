import UIKit

class BrowserViewController: UISplitViewController, UISplitViewControllerDelegate {
    
    var videosViewController: VideosViewController!
    
    override func viewDidLoad() {
        
        // HACK: All visible if possible
        self.preferredDisplayMode = .AllVisible
        
        // The categories view does not need to be so wide (320 is the default)
        self.maximumPrimaryColumnWidth = 260
        self.delegate = self
    }

    func splitViewController(svc: UISplitViewController, willChangeToDisplayMode displayMode: UISplitViewControllerDisplayMode) {
        self.videosViewController.splitViewControllerDidChangeDisplayMode()
    }
}

