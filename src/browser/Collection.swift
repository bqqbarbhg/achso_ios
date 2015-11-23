import Foundation

class Collection {
    
    var title: String
    
    var videos: [VideoInfo] = []

    init(title: String) {
        self.title = title
    }
    
}
