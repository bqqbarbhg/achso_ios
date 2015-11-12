import UIKit
import CoreGraphics

class SeekBarLayer: CALayer {
 
    // Parameters
    var seekBarPositionRelative: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    // Visual measures
    var seekBarHeight: CGFloat = 2.0
    var seekBallDiameter: CGFloat = 7.0
    var sidePadding: CGFloat = 0.0
    
    var requiredSidePadding: CGFloat {
        return seekBallDiameter / 2.0 + 1.0
    }
    
    // Visual colors
    var barBackgroundColor: CGColor = hexCgColor(0x777777, alpha: 0.5)
    var barFillColor: CGColor = hexCgColor(0xFF3333, alpha: 1.0)

    override func drawInContext(ctx: CGContext) {
        super.drawInContext(ctx)

        let middle = frame.height / 2.0
        
        // Fit the bar so that the ball has enough space on both sides without clipping
        let bounds = CGRect(x: self.sidePadding, y: 0.0,
            width: self.frame.width - self.sidePadding * 2.0,
            height: self.frame.height)
        
        // Bounds for the whole bar
        let barBounds = CGRect(x: bounds.minX, y: middle - seekBarHeight / 2.0,
            width: bounds.width, height: seekBarHeight)
        
        // Split the whole bar into filled and unfilled portions
        let splitted = barBounds.divide(barBounds.width * seekBarPositionRelative, fromEdge: CGRectEdge.MinXEdge)
        let filledBounds = splitted.slice
        let backgroundBounds = splitted.remainder
        
        // Filled bar part
        CGContextBeginPath(ctx)
        CGContextAddRect(ctx, filledBounds)
        CGContextSetFillColorWithColor(ctx, barFillColor)
        CGContextFillPath(ctx)
        
        // Unfilled bar part
        CGContextBeginPath(ctx)
        CGContextAddRect(ctx, backgroundBounds)
        CGContextSetFillColorWithColor(ctx, barBackgroundColor)
        CGContextFillPath(ctx)

        // Ball in the middle
        CGContextBeginPath(ctx)
        CGContextAddArc(ctx, filledBounds.maxX, middle, self.seekBallDiameter / 2.0, 0.0, CGFloat(M_PI * 2.0), 1)
        CGContextSetFillColorWithColor(ctx, barFillColor)
        CGContextFillPath(ctx)
    }
    
}