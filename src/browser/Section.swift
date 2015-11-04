import Foundation

class Section {
    
    var title: String?
    
    var collections: [Collection] = []
    
    init(title: String?) {
        self.title = title
    }
}
