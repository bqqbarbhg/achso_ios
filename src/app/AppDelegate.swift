import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Connect the parts of the split view
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        
        let categoriesNavController = splitViewController.viewControllers[0] as! UINavigationController
        let videosNavController = splitViewController.viewControllers[1] as! UINavigationController
        
        let categoriesViewController = categoriesNavController.topViewController as! CategoriesViewController
        let videosViewController = videosNavController.topViewController as! VideosViewController
        
        categoriesViewController.videosViewController = videosViewController
        videosViewController.categoriesViewController = categoriesViewController
        
        // HACK: Extract video collections out of CategoriesViewController
        // Compiled crash: /usr/bin/swift -frontend -c
        // videosViewController.showCollection(categoriesViewController.tempGetSections().first!.collections.first)
        videosViewController.showCollection(categoriesViewController.tempGetSections()[0].collections[0])
        
        if let
            endpointString: String = Secrets.get("LAYERS_OIDC_URL"),
            endpoint: NSURL = NSURL(string: endpointString),
            clientId: String = Secrets.get("LAYERS_OIDC_CLIENT_ID"),
            clientSecret: String = Secrets.get("LAYERS_OIDC_CLIENT_SECRET") {
        
                HTTPClient.setupOIDC(endPointUrl: endpoint, clientId: clientId, clientSecret: clientSecret)
        }
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
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
        videoModel.setValue(manifest, forKey: "manifest")
        
        try self.managedObjectContext.save()
    }
    
    enum AppDataError: ErrorType {
        case UnexpectedResultFormat
    }
    
    func getVideos() throws -> [Video] {
        let fetch = NSFetchRequest(entityName: "Video")
        
        let resultsAny = try self.managedObjectContext.executeFetchRequest(fetch)
        guard let results = resultsAny as? [NSManagedObject] else {
            throw AppDataError.UnexpectedResultFormat
        }
        
        let videos = results.map { result -> Video? in
            guard let manifest = result.valueForKey("manifest") as? String else {
                return nil
            }
            guard let json = parseJson(manifest) else {
                return nil
            }
            return try? Video(manifest: json)
        }
        return videos.filter { $0 != nil }.map { $0! }
    }
}

