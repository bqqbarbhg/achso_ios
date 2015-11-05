import UIKit

class VideoViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    
    func update(video: Video) {
        titleLabel.text = video.title
    }
    
}
