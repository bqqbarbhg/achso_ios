import Foundation

class Collection {
    
    enum Type {
        case General
        case Group
    }
    
    var title: String
    var subtitle: String?
    var type: Type
    
    // Cleanup: This should be in the enum but doesn't go there cleanly
    var extra: AnyObject?
    
    var videos: [VideoInfo] = []

    init(title: String, subtitle: String?, type: Type, extra: AnyObject? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.extra = extra
    }
    
}
