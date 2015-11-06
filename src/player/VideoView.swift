import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

protocol VideoViewDelegate {
    func videoViewEvent(event: PlayerUserEvent)
}

class VideoView: UIView {
    
    let avPlayerView: AVPlayerView
    let seekBarView: SeekBarView

    var seekBarVisible: Bool = true
    
    var delegate: VideoViewDelegate?
    
    var player: VideoPlayer?
    
    var annotationLayer: AnnotationLayer
    
    required init?(coder aDecoder: NSCoder) {
        self.avPlayerView = AVPlayerView()
        self.seekBarView = SeekBarView()
        self.annotationLayer = AnnotationLayer()

        super.init(coder: aDecoder)
        
        self.backgroundColor = UIColor.blackColor()
        
        self.avPlayerView.layer.addSublayer(self.annotationLayer)
        
        self.addSubview(self.avPlayerView)
        self.addSubview(self.seekBarView)
    }
    
    override func layoutSubviews() {
        
        let containerSize = self.frame.size
        guard let videoSize = self.player?.videoSize else { return }
        
        let fittedSize = videoSize.fitInside(containerSize)

        let frame = self.frame.pinToCenter(fittedSize)
        
        self.annotationLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: frame.size)
        self.avPlayerView.frame = frame

        self.annotationLayer.setNeedsDisplay()

        let seekBarFrame = self.frame.divide(50.0, fromEdge: CGRectEdge.MaxYEdge).slice
        self.seekBarView.frame = seekBarFrame
        
        seekBarView.setNeedsDisplay()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            if self.seekBarVisible {
                if let action = seekBarView.interpretTouch(touch) {
                    delegate?.videoViewEvent(action)
                } else {
                    // HACKish: Detect tap better
                    self.seekBarVisible = false
                    UIView.animateWithDuration(0.3, animations: {
                        self.seekBarView.alpha = 0.0
                    })
                }
            } else {
                // HACKish: Detect tap better
                self.seekBarVisible = true
                UIView.animateWithDuration(0.3, animations: {
                    self.seekBarView.alpha = 1.0
                })
            }
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            if let action = seekBarView.interpretTouch(touch) {
                delegate?.videoViewEvent(action)
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            if let action = seekBarView.interpretTouch(touch) {
                delegate?.videoViewEvent(action)
            }
        }
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        guard let realTouches = touches else { return }
        
        for touch in realTouches {
            if let action = seekBarView.interpretTouch(touch) {
                delegate?.videoViewEvent(action)
            }
        }
        
    }
    
    func attachPlayer(player: VideoPlayer) {
        avPlayerView.attachPlayer(player)
        self.player = player
        self.setNeedsLayout()
        
        player.avPlayer.addPeriodicTimeObserverForInterval(CMTimeMake(1, 60), queue: nil, usingBlock: timeUpdate)
    }
    
    func timeUpdate(time: CMTime) {
        let seconds = time.seconds
        
        if let duration = self.player?.videoDuration {
            self.seekBarView.update(seconds / duration)
        }
    }
    
    func showAnnotations(annotations: [Annotation]) {
        annotationLayer.annotations = annotations
        annotationLayer.setNeedsDisplay()
    }
}
