import UIKit

class CategoriesViewController: UITableViewController, VideoRepositoryListener {
    
    // Initialized in didFinishLaunch, do not use in init
    weak var videosViewController: VideosViewController!
    
    var collections: [Collection] = []
    var sections: [Section] = []
    
    var isEnabled: Bool = true
    
    func updateSections() {
        let groupedCollections = self.collections.groupBy({ $0.type })
        
        let general = Section(title: nil)
        general.collections = groupedCollections[.General] ?? []
        
        let genres = Section(title: NSLocalizedString("Genres", comment: "Title of a category section"))
        genres.collections = groupedCollections[.Genre] ?? []
        
        let groups = Section(title: NSLocalizedString("Groups", comment: "Title of a category section"))
        groups.collections = groupedCollections[.Group] ?? []
        
        self.sections = [general, genres, groups]
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
        cell.textLabel?.enabled = self.isEnabled
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let collection = self.sections[safe: indexPath.section]?.collections[safe: indexPath.item]
        
        if let index = self.collections.indexOf({ $0 === collection}) {
            self.videosViewController.showCollection(index)
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
    
    @IBAction func addButtonPressed(sender: UIBarButtonItem) {
        
        do {
            let sharesNav = self.storyboard!.instantiateViewControllerWithIdentifier("SharesViewController") as! UINavigationController
            let sharesController = sharesNav.topViewController as! SharesViewController
            try sharesController.prepareForCreateGroup()
            self.presentViewController(sharesNav, animated: true) {
            }
        } catch {
            self.showErrorModal(error, title: NSLocalizedString("error_on_create_group", comment: "Error title shown when creating a group was interrupted"))
        }
        
    }
    
    @IBAction func loginButtonPressed(sender: UIBarButtonItem) {
        HTTPClient.authenticate(fromViewController: self) { result in
            if let error = result.error {
                self.showErrorModal(error, title: NSLocalizedString("error_on_sign_in",
                    comment: "Error title when trying to sign in"))
            } else {
                videoRepository.refreshOnline()
            }
        }
    }
    
}
