import UIKit

class VideosViewController: UIViewController {
    
    // Initialized in didFinishLaunch, do not use in init
    weak var categoriesViewController: CategoriesViewController!
    
    func showCollection(collection: Collection) {
        self.title = collection.title
    }
    
}
