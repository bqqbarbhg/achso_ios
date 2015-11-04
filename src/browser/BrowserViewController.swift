import UIKit

class BrowserViewController: UISplitViewController {
    
    override func viewDidLoad() {
        
        // TODO: This is not needed if there is some button on tablet that opens the categories
        self.preferredDisplayMode = UISplitViewControllerDisplayMode.AllVisible
    }
    
}

