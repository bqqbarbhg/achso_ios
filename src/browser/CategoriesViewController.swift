import UIKit

class CategoriesViewController: UITableViewController, VideoRepositoryListener {
    
    // Initialized in didFinishLaunch, do not use in init
    weak var videosViewController: VideosViewController!
    
    var collections: [Collection] = []
    var sections: [Section] = []
    
    func updateSections() {
        let general = Section(title: nil)
        general.collections = self.collections
        
        self.sections = [general]
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        videoRepository.addListener(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        videoRepository.removeListener(self)
    }
    
    func videoRepositoryUpdated() {
        self.collections = videoRepository.collections
        updateSections()
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.sections.count;
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].collections.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].title
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("CategoryCell", forIndexPath: indexPath)
        
        let collection = self.sections[safe: indexPath.section]?.collections[safe: indexPath.item]
        cell.textLabel?.text = collection?.title
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let collection = self.sections[safe: indexPath.section]?.collections[safe: indexPath.item]
        
        if let index = self.collections.indexOf({ $0 === collection}) {
            self.videosViewController.showCollection(index)
            self.splitViewController?.showDetailViewController(self.videosViewController.navigationController!, sender: nil)
        }
    }
}
