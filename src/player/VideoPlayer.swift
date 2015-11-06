import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

class VideoPlayer {
    
    var avPlayer: AVPlayer
    var videoSize: CGSize?
    
    init() {
        self.avPlayer = AVPlayer()
        self.avPlayer.actionAtItemEnd = .Pause
        
        // TODO: TimeUpdate
        // avPlayer.addPeriodicTimeObserverForInterval(CMTimeMake(1, 60), queue: nil, usingBlock: timeUpdate)
    }
    
    func getVideoSizeFromAsset(asset: AVURLAsset) -> CGSize? {
        guard let videoTrack = asset.tracksWithMediaType(AVMediaTypeVideo).first else {
            return nil
        }
        
        let naturalSize = videoTrack.naturalSize
        let affineTransform = videoTrack.preferredTransform
        
        let transformedSize = CGSizeApplyAffineTransform(naturalSize, affineTransform)
        return transformedSize.asPositive()
    }
    
    func loadVideo(url: NSURL) {
        let asset = AVURLAsset(URL: url, options: .None)
        let playerItem = AVPlayerItem(asset: asset)
        
        self.videoSize = getVideoSizeFromAsset(asset)
        self.avPlayer.replaceCurrentItemWithPlayerItem(playerItem)
    }
    
    func play() {
        self.avPlayer.play()
    }
}
