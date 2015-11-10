import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

class VideoView: UIView {
    
    var callback: ((AnnotationEditEvent) -> ())?
    
    let avPlayerView: AVPlayerView
    var player: VideoPlayer?
    
    var annotationLayer: AnnotationLayer
    
    required init?(coder aDecoder: NSCoder) {
        
        self.avPlayerView = AVPlayerView()
        self.annotationLayer = AnnotationLayer()

        super.init(coder: aDecoder)
        
        self.backgroundColor = UIColor.blackColor()
        
        self.annotationLayer.contentsScale = UIScreen.mainScreen().scale
        self.avPlayerView.layer.addSublayer(self.annotationLayer)
        
        self.addSubview(self.avPlayerView)
    }
    
    override func layoutSubviews() {
        
        super.layoutSubviews()
        
        let containerSize = self.frame.size
        guard let videoSize = self.player?.videoSize else { return }
        
        let fittedSize = videoSize.fitInside(containerSize)

        let frame = self.frame.pinToCenter(fittedSize)
        
        self.annotationLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: frame.size)
        self.avPlayerView.frame = frame

        self.annotationLayer.setNeedsDisplay()
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let position = Vector2(cgPoint: touch.locationInView(self.avPlayerView))
            let normalized = position / Vector2(cgSize: self.avPlayerView.frame.size)
            self.callback?(AnnotationEditEvent(position: normalized, state: .Begin))
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let position = Vector2(cgPoint: touch.locationInView(self.avPlayerView))
            let normalized = position / Vector2(cgSize: self.avPlayerView.frame.size)
            self.callback?(AnnotationEditEvent(position: normalized, state: .Move))
        }
    }
    
    func attachPlayer(player: VideoPlayer) {
        avPlayerView.attachPlayer(player)
        self.player = player
        self.setNeedsLayout()
    }
    
    func showAnnotations(annotations: [Annotation]) {
        annotationLayer.annotations = annotations
        annotationLayer.setNeedsDisplay()
    }
}
