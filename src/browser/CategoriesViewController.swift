import UIKit

class CategoriesViewController: UITableViewController, VideoRepositoryListener {
    
    class Section {
        
        var title: String?
        
        var collections: [CollectionIdentifier] = []
        
        init(title: String?) {
            self.title = title
        }
    }
    
    // Initialized in didFinishLaunch, do not use in init
    weak var videosViewController: VideosViewController!
    
    var collectionIds: [CollectionIdentifier] = []
    var sections: [Section] = []
    
    var isEnabled: Bool = true
    
    func updateSections() {
        
        let general = Section(title: nil)
        general.collections = [.AllVideos]
        
        let groups = Section(title: NSLocalizedString("Groups", comment: "Title of a category section"))
        groups.collections = videoRepository.groups.map { .Group($0.id) }
        
        self.sections = [general, groups]
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        videoRepository.addListener(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        videoRepository.removeListener(self)
    }
    
    func videoRepositoryUpdated() {
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
        
        if let collectionId = self.sections[safe: indexPath.section]?.collections[safe: indexPath.item],
                collection = videoRepository.retrieveCollectionByIdentifier(collectionId) {
            cell.textLabel?.text = collection.title
            cell.detailTextLabel?.text = collection.subtitle
            cell.detailTextLabel?.numberOfLines = 2
            cell.detailTextLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        } else {
            cell.textLabel?.text = nil
        }
        cell.textLabel?.enabled = self.isEnabled
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let maybeCollection = self.sections[safe: indexPath.section]?.collections[safe: indexPath.item]
        
        if let collection = maybeCollection {
            self.videosViewController.showCollection(collection)
            self.splitViewController?.showDetailViewController(self.videosViewController.navigationController!, sender: nil)
        }
    }
    
    func setEnabled(enabled: Bool) {
        self.isEnabled = enabled
        
        self.view.userInteractionEnabled = enabled
        self.navigationItem.rightBarButtonItem?.enabled = enabled
        self.navigationItem.leftBarButtonItem?.enabled = enabled
        for cell in self.tableView.visibleCells {
            cell.textLabel?.enabled = enabled
        }
        let sections = self.numberOfSectionsInTableView(self.tableView)
        for header in (0..<sections).flatMap(self.tableView.headerViewForSection) {
            header.textLabel?.enabled = enabled
        }
    }
    
    @IBAction func editButtonPressed(sender: UIBarButtonItem) {
        
        do {
            let sharesNav = self.storyboard!.instantiateViewControllerWithIdentifier("SharesViewController") as! UINavigationController
            let sharesController = sharesNav.topViewController as! SharesViewController
            try sharesController.prepareForManageGroups()
            self.presentViewController(sharesNav, animated: true) {
            }
        } catch {
            self.showErrorModal(error, title: NSLocalizedString("error_on_create_group", comment: "Error title shown when creating a group was interrupted"))
        }
        
    }
    
}
