/*

`GradientLayer` is just a simple `CALayer` that just fills the area with a gradient.
It is used in VideoCellView.swift to make the dark gradient over the thumbnail.

*/

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

