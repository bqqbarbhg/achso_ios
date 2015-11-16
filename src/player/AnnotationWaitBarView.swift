import UIKit

class AnnotationWaitBarView: UIView {
    
    let progressLayer: CALayer = CALayer()
    
    init() {
        super.init(frame: CGRectZero)
        self.setup()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    func setup() {
        self.opaque = false
        self.backgroundColor = nil
        
        self.progressLayer.hidden = true
        self.progressLayer.opaque = false
        self.progressLayer.backgroundColor = hexCgColor(0xFF0000, alpha: 1.0)
        
        self.layer.addSublayer(self.progressLayer)
    }
    
    override func layoutSublayersOfLayer(layer: CALayer) {
        if layer === self.layer {
            self.progressLayer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
            self.progressLayer.frame = layer.bounds
        }
    }
    
    func animateProgress(duration: Double) {
        
        let beginValue = self.progressLayer.bounds.divide(0.0, fromEdge: CGRectEdge.MinXEdge).slice
        let endValue = self.progressLayer.bounds
        
        self.progressLayer.hidden = false
        self.progressLayer.opacity = 1.0
        
        let animation = CABasicAnimation(keyPath: "bounds")
        animation.fromValue = NSValue(CGRect: beginValue)
        animation.toValue = NSValue(CGRect: endValue)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        self.progressLayer.addAnimation(animation, forKey: "bounds")
    }
    
    func stopAnimation() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut))
        
        self.progressLayer.opacity = 0.0
        
        CATransaction.setCompletionBlock({
            self.progressLayer.hidden = true
        })
        CATransaction.commit()
    }
}
