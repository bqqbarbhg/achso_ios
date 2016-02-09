/*

`CategoriesViewController` is the left-hand side view in the browsing activity. It manages a list view of the groups and changes the data source of VideosViewController.swift .

*/

import UIKit

class CategoriesViewController: UITableViewController, VideoRepositoryListener {
    
    // Represents a section in the table view with related collections of videos.
    class Section {
        let title: String?
        let collections: [CollectionIdentifier]
        
        init(title: String?, collections: [CollectionIdentifier]) {
            self.title = title
            self.collections = collections
        }
    }
    
    // Initialized in didFinishLaunch, do not use in init
    weak var videosViewController: VideosViewController!
    
    var collectionIds: [CollectionIdentifier] = []
    var sections: [Section] = []
    
    func updateSections() {
        
        let general = Section(title: nil, collections: [.AllVideos])

        let groups = Section(
            title: NSLocalizedString("Groups", comment: "Title of a category section"),
            collections: videoRepository.groups.map { .Group($0.id) })
        
        self.sections = [general, groups]
        self.tableView.reloadData()
    }
    
    func videoRepositoryUpdated() {
        updateSections()
    }
    
    override func viewWillAppear(animated: Bool) {
        videoRepository.addListener(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        videoRepository.removeListener(self)
    }
    
    // MARK: - table view
    
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
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let maybeCollection = self.sections[safe: indexPath.section]?.collections[safe: indexPath.item]
        
        if let collection = maybeCollection {
            self.videosViewController.showCollection(collection)
            self.splitViewController?.showDetailViewController(self.videosViewController.navigationController!, sender: nil)
        }
    }
    
    // MARK: - buttons
    
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
