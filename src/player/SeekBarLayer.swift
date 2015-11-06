import UIKit
import CoreGraphics

class SeekBarLayer: CALayer {
 
    // Parameters
    var seekBarPosition: CGFloat = 0.0
    
    // Visual measures
    var seekBarHeight: CGFloat = 3.0
    var seekBallDiameter: CGFloat = 7.0
    
    // Visual colors
    var barBackgroundColor: CGColor = hexCgColor(0x777777, alpha: 0.5)
    var barFillColor: CGColor = hexCgColor(0xFF3333, alpha: 1.0)

    override func drawInContext(ctx: CGContext) {
        
        super.drawInContext(ctx)

        let middle = frame.height / 2.0
        
        let bounds = CGRect(x: self.seekBallDiameter / 2.0, y: 0.0,
            width: self.frame.width - self.seekBallDiameter,
            height: self.frame.height)
        
        let barBounds = CGRect(x: bounds.minX, y: middle - seekBarHeight / 2.0,
            width: bounds.width, height: seekBarHeight)
        
        let splitted = barBounds.divide(barBounds.width * seekBarPosition, fromEdge: CGRectEdge.MinXEdge)
        
        let filledBounds = splitted.slice
        let backgroundBounds = splitted.remainder
        
        CGContextBeginPath(ctx)
        CGContextAddRect(ctx, filledBounds)
        CGContextSetFillColorWithColor(ctx, barFillColor)
        CGContextFillPath(ctx)
        
        CGContextBeginPath(ctx)
        CGContextAddRect(ctx, backgroundBounds)
        CGContextSetFillColorWithColor(ctx, barBackgroundColor)
        CGContextFillPath(ctx)

        CGContextBeginPath(ctx)
        CGContextAddArc(ctx, filledBounds.maxX, middle, self.seekBallDiameter / 2.0, 0.0, CGFloat(M_PI * 2.0), 1)
        CGContextSetFillColorWithColor(ctx, barFillColor)
        CGContextFillPath(ctx)
    }
    
}