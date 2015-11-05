import UIKit

class BrowserViewController: UISplitViewController {
    
    override func viewDidLoad() {
        
        // TODO: This is not needed if there is some button on tablet that opens the categories
        self.preferredDisplayMode = UISplitViewControllerDisplayMode.AllVisible
        
        // The categories view does not need to be so wide (320 is the default)
        self.maximumPrimaryColumnWidth = 260
    }
    
}

