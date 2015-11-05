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
    
    func loadVideo(url: NSURL) {
        let asset = AVURLAsset(URL: url, options: .None)
        let playerItem = AVPlayerItem(asset: asset)
        
        self.videoSize = asset.tracksWithMediaType(AVMediaTypeVideo).first?.naturalSize
        self.avPlayer.replaceCurrentItemWithPlayerItem(playerItem)
    }
    
    func play() {
        self.avPlayer.play()
    }
}
