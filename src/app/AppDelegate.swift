import UIKit
import CoreData
import SDWebImage

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    static var instance: AppDelegate {
        return UIApplication.sharedApplication().delegate as! AppDelegate
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Connect the parts of the split view
        let browserViewController = self.window!.rootViewController as! BrowserViewController
        
        let categoriesNavController = browserViewController.viewControllers[0] as! UINavigationController
        let videosNavController = browserViewController.viewControllers[1] as! UINavigationController
        
        let categoriesViewController = categoriesNavController.topViewController as! CategoriesViewController
        let videosViewController = videosNavController.topViewController as! VideosViewController
        
        categoriesViewController.videosViewController = videosViewController
        videosViewController.categoriesViewController = categoriesViewController
        browserViewController.videosViewController = videosViewController
        
        // HACK: Extract video collections out of CategoriesViewController
        // Compiled crash: /usr/bin/swift -frontend -c
        // videosViewController.showCollection(categoriesViewController.tempGetSections().first!.collections.first)
        videosViewController.showCollection(0)
        
        if let
            endpointString: String = Secrets.get("LAYERS_OIDC_URL"),
            endpoint: NSURL = NSURL(string: endpointString),
            clientId: String = Secrets.get("LAYERS_OIDC_CLIENT_ID"),
            clientSecret: String = Secrets.get("LAYERS_OIDC_CLIENT_SECRET") {
        
                HTTPClient.setupOIDC(endPointUrl: endpoint, clientId: clientId, clientSecret: clientSecret)
        }
        
        loadUserSession()
        videoRepository.refresh()
        
        SDWebImageManager.sharedManager().delegate = ImageLoader.instance
        
        return true
    }
    
    func saveUserSession() {
        if let user = AuthUser.user {
            NSKeyedArchiver.archiveRootObject(user, toFile: AuthUser.ArchiveURL.path!)
        }
    }
    
    func loadUserSession() {
        AuthUser.user = NSKeyedUnarchiver.unarchiveObjectWithFile(AuthUser.ArchiveURL.path!) as? AuthUser
        HTTPClient.tempSetup()
    }
    
    func saveGroups(groups: [Group], downloadedBy: String) {
        let groupList = GroupList(groups: groups, downloadedBy: downloadedBy)
        NSKeyedArchiver.archiveRootObject(groupList, toFile: GroupList.ArchiveURL.path!)
    }
    
    func loadGroups() -> [Group]? {
        guard let groupList = NSKeyedUnarchiver.unarchiveObjectWithFile(GroupList.ArchiveURL.path!) as? GroupList else {
            return nil
        }
        
        if groupList.downloadedBy != AuthUser.user?.id {
            return nil
        }
        
        return groupList.groups
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        saveUserSession()
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        loadUserSession()
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        saveUserSession()
        self.saveContext()
    }
    
    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "fi.aalto.legroup.AchSo" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
        }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("AchSo", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("AchSoCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
        }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    // Core data wrappers
    
    lazy var videoEntity: NSEntityDescription = NSEntityDescription.entityForName("Video", inManagedObjectContext: self.managedObjectContext)!
    
    func findVideoModel(id: NSUUID) throws -> NSManagedObject? {
        let fetch = NSFetchRequest(entityName: "Video")
        fetch.predicate = NSPredicate(format: "id == %@", argumentArray: [id.lowerUUIDString])
        fetch.fetchLimit = 1
        
        let results = try self.managedObjectContext.executeFetchRequest(fetch)
        return results[safe: 0] as? NSManagedObject
    }
    
    func createVideoModel(id: NSUUID) throws -> NSManagedObject {
        let videoModel = NSManagedObject(entity: self.videoEntity, insertIntoManagedObjectContext: self.managedObjectContext)
        
        videoModel.setValue(id.lowerUUIDString, forKey: "id")
        
        return videoModel
    }
    
    func saveVideo(video: Video) throws {
        let manifest: String = try stringifyJson(video.toManifest()).unwrap()
        
        let videoModel = try findVideoModel(video.id) ?? createVideoModel(video.id)
        
        let videoInfo = VideoInfo(video: video)
        
        videoInfo.writeToObject(videoModel)
        videoModel.setValue(manifest, forKey: "manifest")
        
        try self.managedObjectContext.save()
    }
    
    enum AppDataError: ErrorType {
        case UnexpectedResultFormat
    }
    
    func getVideoInfos() throws -> [VideoInfo] {
        let fetch = NSFetchRequest(entityName: "Video")
        fetch.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        if let user = AuthUser.user {
            fetch.predicate = NSPredicate(format: "downloadedBy == %@ OR isLocal == TRUE", argumentArray: [user.id])
        } else {
            fetch.predicate = NSPredicate(format: "isLocal == TRUE")
        }
        
        let resultsAny = try self.managedObjectContext.executeFetchRequest(fetch)
        guard let results = resultsAny as? [NSManagedObject] else {
            throw AppDataError.UnexpectedResultFormat
        }
        
        return results.flatMap { try? VideoInfo(object: $0) }
    }
    
    func getVideo(id: NSUUID) throws -> Video? {
        guard let videoModel = try findVideoModel(id) else {
            return nil
        }
        
        let manifestString = try (videoModel.valueForKey("manifest") as? String).unwrap()
        let locallyModified = try (videoModel.valueForKey("hasLocalModifications") as? Bool).unwrap()
        let downloadedBy = videoModel.valueForKey("downloadedBy") as? String
        return try Video(manifest: parseJson(manifestString).unwrap(),
            hasLocalModifications: locallyModified,
            downloadedBy: downloadedBy)
    }
}

