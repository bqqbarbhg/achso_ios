import UIKit

class GradientLayer: CALayer {
    
    var gradient: CGGradient
    
    override init(layer: AnyObject) {
        self.gradient = (layer as! GradientLayer).gradient
        super.init(layer: layer)
    }
    
    init(gradient: CGGradient) {
        self.gradient = gradient
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawInContext(ctx: CGContext) {
        
        CGContextDrawLinearGradient(ctx, self.gradient,
            CGPoint(x: self.frame.midX, y: self.frame.minY),
            CGPoint(x: self.frame.midX, y: self.frame.midY),
            CGGradientDrawingOptions(rawValue: 0))
        
    }
}

