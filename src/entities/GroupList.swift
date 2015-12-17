import Foundation

class GroupList: NSObject, NSCoding {
    
    var groups: [Group]
    var user: User
    var downloadedBy: String
    
    static let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.URLByAppendingPathComponent("group_list")
    
    init(groups: [Group], user: User, downloadedBy: String) {
        
        self.groups = groups
        self.user = user
        self.downloadedBy = downloadedBy
        
        super.init()
    }
    
    required convenience init?(coder aCoder: NSCoder) {
        do {
            let groups = try (aCoder.decodeObjectForKey("groups") as? [Group]).unwrap()
            let user = try (aCoder.decodeObjectForKey("user") as? User).unwrap()
            let downloadedBy = try (aCoder.decodeObjectForKey("downloadedBy") as? String).unwrap()
            self.init(groups: groups, user: user, downloadedBy: downloadedBy)
        } catch {
            return nil
        }
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.groups, forKey: "groups")
        aCoder.encodeObject(self.user, forKey: "user")
        aCoder.encodeObject(self.downloadedBy, forKey: "downloadedBy")
    }
}
