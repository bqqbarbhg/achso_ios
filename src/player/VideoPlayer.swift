import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

protocol VideoPlayerDelegate {
    func timeUpdate(time: Double)
}

class VideoPlayer {
    
    var avPlayer: AVPlayer
    var videoSize: CGSize?
    var videoDuration: Double?
    
    var delegate: VideoPlayerDelegate?
    
    init(url: NSURL) {
        self.avPlayer = AVPlayer()
        self.avPlayer.actionAtItemEnd = .Pause
        
        let asset = AVURLAsset(URL: url, options: .None)
        let playerItem = AVPlayerItem(asset: asset)
        
        self.videoSize = getVideoSizeFromAsset(asset)
        self.videoDuration = asset.duration.seconds
        
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.addPeriodicTimeObserverForInterval(CMTimeMake(1, 60), queue: nil, usingBlock: timeUpdate)
        
        self.avPlayer = avPlayer
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
    
    func seekTo(time: Double) {
        
        // Always seek to _exactly_ where the user wants.
        let tolerance = CMTimeMake(0, 1000)
        
        self.avPlayer.seekToTime(CMTimeMakeWithSeconds(Float64(time), 1000),
            toleranceBefore: tolerance, toleranceAfter: tolerance)
    }
    
    func timeUpdate(time: CMTime) {
        self.delegate?.timeUpdate(time.seconds)
    }
    
    func pause() {
        self.avPlayer.pause()
    }
    
    func play() {
        self.avPlayer.play()
    }
}
