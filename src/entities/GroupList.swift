import Foundation

class GroupList: NSObject, NSCoding {
    
    var groups: [Group]
    var downloadedBy: String
    
    static let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.URLByAppendingPathComponent("group_list")
    
    init(groups: [Group], downloadedBy: String) {
        
        self.groups = groups
        self.downloadedBy = downloadedBy
        
        super.init()
    }
    
    required convenience init?(coder aCoder: NSCoder) {
        do {
            let groups = try (aCoder.decodeObjectForKey("groups") as? [Group]).unwrap()
            let downloadedBy = try (aCoder.decodeObjectForKey("downloadedBy") as? String).unwrap()
            self.init(groups: groups, downloadedBy: downloadedBy)
        } catch {
            return nil
        }
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.groups, forKey: "groups")
        aCoder.encodeObject(self.downloadedBy, forKey: "downloadedBy")
    }
}
