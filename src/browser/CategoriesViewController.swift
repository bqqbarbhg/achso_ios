import UIKit

class CategoriesViewController: UITableViewController {
    
    // Initialized in didFinishLaunch, do not use in init
    weak var videosViewController: VideosViewController!
    
    func tempGetSections() -> [Section] {
        
        let general = Section(title: nil)
        general.collections = [
            Collection(title: "All videos"),
            Collection(title: "My videos"),
        ]
        
        func makeVideo(title: String) -> Video {
            let video = Video()
            video.title = title
            return video
        }
        
        general.collections[0].videos = [
            makeVideo("Miestentie"),
            makeVideo("Another video"),
            makeVideo("Third video"),
        ]
        
        for i in 1...10 {
            general.collections[0].videos.append(makeVideo("Video #\(i)"))
        }
        
        let genres = Section(title: "Genres")
        genres.collections = [
            Collection(title: "Good work"),
            Collection(title: "Problem"),
            Collection(title: "Site overview"),
            Collection(title: "Trick of trade"),
        ]
        
        let groups = Section(title: "Groups")
        groups.collections = [
            Collection(title: "LeGroup"),
            Collection(title: "Test group"),
        ]
        
        return [general, genres, groups];
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
