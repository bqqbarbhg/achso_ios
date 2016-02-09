/*

`Collection` is a filtered collection of videos by some criteria.

*/

import Foundation

class Collection {
    
    let videos: [VideoInfo]
    
    let title: String
    let subtitle: String?

    init(videos: [VideoInfo], title: String, subtitle: String? = nil) {
        self.videos = videos
        self.title = title
        self.subtitle = subtitle
    }
    
}
