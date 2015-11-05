import UIKit

class VideoView: UIView {
    
    let avPlayerView: AVPlayerView
    var player: VideoPlayer?
    
    var annotationLayer: AnnotationLayer
    
    required init?(coder aDecoder: NSCoder) {
        self.avPlayerView = AVPlayerView()
        self.annotationLayer = AnnotationLayer()

        super.init(coder: aDecoder)
        
        self.avPlayerView.layer.addSublayer(self.annotationLayer)
        self.addSubview(self.avPlayerView)
    }
    
    override func layoutSubviews() {
        
        let containerSize = self.frame.size
        guard let videoSize = self.player?.videoSize else { return }
        
        let fittedSize = videoSize.fitInside(containerSize)

        let frame = CGRect(origin: self.frame.origin, size: fittedSize)
        
        self.annotationLayer.setNeedsDisplay()
        
        self.annotationLayer.frame = frame
        self.avPlayerView.frame = frame
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
