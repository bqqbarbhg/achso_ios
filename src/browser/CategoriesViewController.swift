import UIKit

class CategoriesViewController: UITableViewController {
    
    // Initialized in didFinishLaunch, do not use in init
    weak var videosViewController: VideosViewController!
    
    var tempVideos: [VideoInfo] = []

    var tempAllVideos = Collection(title: "All Videos")
    
    func tempGetSections() -> [Section] {
        let general = Section(title: nil)
        general.collections = [tempAllVideos]
        tempAllVideos.videos = tempVideos
        
        return [general]
    }
    
    override func viewWillAppear(animated: Bool) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        self.tempVideos = (try? appDelegate.getVideoInfos()) ?? []
        self.tableView.reloadData()
        
        // HACK: Think about load order
        // This doesn't even work on phone
        self.videosViewController.collectionView?.reloadData()
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return tempGetSections().count;
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tempGetSections()[section].collections.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tempGetSections()[section].title
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("CategoryCell", forIndexPath: indexPath)
        
        let collection = tempGetSections()[indexPath.section].collections[indexPath.item]
        cell.textLabel?.text = collection.title
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let collection = tempGetSections()[indexPath.section].collections[indexPath.item]
        
        self.videosViewController.showCollection(collection)
        self.splitViewController?.showDetailViewController(self.videosViewController.navigationController!, sender: nil)
    }
}
