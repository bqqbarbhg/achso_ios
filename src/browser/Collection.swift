import Foundation

class Collection {
    
    enum Type {
        case General
        case Genre
        case Group
    }
    
    var title: String
    var type: Type
    
    var videos: [VideoInfo] = []

    init(title: String, type: Type) {
        self.title = title
        self.type = type
    }
    
}
