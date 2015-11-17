import UIKit
import AVKit
import AVFoundation

class VideoViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    
    func update(video: Video) {
        titleLabel.text = video.title
        
        // HACK: Do this in background thread
        let asset = AVAsset(URL: video.videoUri)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: asset.duration.seconds / 3.0, preferredTimescale: 1000)
        self.layer.contents = try? imageGenerator.copyCGImageAtTime(time, actualTime: nil)
        self.layer.contentsGravity = kCAGravityResizeAspectFill
    }
    
}
