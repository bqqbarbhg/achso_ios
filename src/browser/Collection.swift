import Foundation

class Collection {
    
    var title: String
    
    var videos: [Video] = []

    init(title: String) {
        self.title = title
    }
    
}
