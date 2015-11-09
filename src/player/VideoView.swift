import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

class VideoView: UIView {
    
    let avPlayerView: AVPlayerView
    var player: VideoPlayer?
    
    var annotationLayer: AnnotationLayer
    
    required init?(coder aDecoder: NSCoder) {
        
        self.avPlayerView = AVPlayerView()
        self.annotationLayer = AnnotationLayer()

        super.init(coder: aDecoder)
        
        self.backgroundColor = UIColor.blackColor()
        
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
