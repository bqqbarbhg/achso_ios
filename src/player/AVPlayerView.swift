import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

class AVPlayerView: UIView {
    
    var playerLayer: AVPlayerLayer! {
        get {
            return self.layer as! AVPlayerLayer
        }
    }
    
    override class func layerClass() -> AnyClass {
        return AVPlayerLayer.self
    }
    
    func attachPlayer(player: VideoPlayer) {
        playerLayer.videoGravity = AVLayerVideoGravityResize
        playerLayer.player = player.avPlayer
    }
}