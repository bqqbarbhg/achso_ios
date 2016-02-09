/*

`VideoPlayer` wraps an `AVPlayer` and hides most of the complexity providing a simple `VideoPlayerDelegate` API.

*/

import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

protocol VideoPlayerDelegate {
    func videoLoaded()
    func videoFailedToLoad()
    func timeUpdate(time: Double)
    func videoEnded()
}

class VideoPlayer: NSObject {
    
    var kvoContext: UInt8 = 1
    
    var avPlayer: AVPlayer
    var asset: AVURLAsset?
    var playerItem: AVPlayerItem?
    var videoSize: CGSize?
    var videoDuration: Double?
    
    var delegate: VideoPlayerDelegate? {
        didSet {
            if let playerItem = self.playerItem {
                switch playerItem.status {
                case .ReadyToPlay:
                    self.onLoaded()
                case .Failed:
                    self.onFailed()
                default:
                    break
                }
            }
        }
    }
    
    init(url: NSURL) {
        self.avPlayer = AVPlayer()
        
        super.init()
        
        self.avPlayer.actionAtItemEnd = .Pause
        
        let asset = AVURLAsset(URL: url, options: .None)
        let playerItem = AVPlayerItem(asset: asset)
        
        playerItem.addObserver(self, forKeyPath: "status", options: .New, context: &self.kvoContext)
        
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.addPeriodicTimeObserverForInterval(CMTimeMake(1, 60), queue: nil, usingBlock: timeUpdate)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "videoEnded:", name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
        
        self.avPlayer = avPlayer
        self.asset = asset
        self.playerItem = playerItem
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.playerItem?.removeObserver(self, forKeyPath: "status")
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context != &self.kvoContext {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        
        if keyPath == "status" {
            guard let status = change![NSKeyValueChangeNewKey]?.integerValue else { return }
            switch AVPlayerItemStatus(rawValue: status)! {
            case .Unknown:
                break
            case .ReadyToPlay:
                self.onLoaded()
            case .Failed:
                self.onFailed()
            }
        }
    }
    
    func onLoaded()
    {
        guard let asset = self.asset else { return }
        self.videoSize = getVideoSizeFromAsset(asset)
        self.videoDuration = asset.duration.seconds
        
        self.delegate?.videoLoaded()
    }
    
    func onFailed()
    {
        self.delegate?.videoFailedToLoad()
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
    
    func videoEnded(notification: NSNotification) {
        self.delegate?.videoEnded()
    }
    
    func pause() {
        self.avPlayer.pause()
    }
    
    func play() {
        self.avPlayer.play()
    }
}
