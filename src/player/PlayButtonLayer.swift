import UIKit
import CoreGraphics

class PlayButtonLayer: CALayer {
    
    // Parameters
    var isPlaying: Bool = false
    var borderPadding: CGFloat = 15.0
    
    // Visual measueres
    var pauseThickness: CGFloat = 0.8
    
    // Visual colors
    var color: CGColor = hexCgColor(0x888888, alpha: 1.0)
    
    override func drawInContext(ctx: CGContext) {
        super.drawInContext(ctx)
        
        let bounds = CGRect(origin: CGPointZero, size: self.frame.size)
            .insetBy(dx: borderPadding, dy: borderPadding)
        
        if isPlaying {
         
            CGContextBeginPath(ctx)
            
            CGContextMoveToPoint(ctx, bounds.maxX, bounds.midY)
            CGContextAddLineToPoint(ctx, bounds.minX, bounds.maxY)
            CGContextAddLineToPoint(ctx, bounds.minX, bounds.minY)
            
            CGContextSetFillColorWithColor(ctx, self.color)
            CGContextFillPath(ctx)
            
        } else {
            
            CGContextBeginPath(ctx)

            let pauseWidth = bounds.width * (self.pauseThickness / 2.0)
            
            CGContextAddRect(ctx, CGRect(x: bounds.minX, y: bounds.minY,
                width: pauseWidth, height: bounds.height))
                
            CGContextAddRect(ctx, CGRect(x: bounds.maxX - pauseWidth, y: bounds.minY,
                width: pauseWidth, height: bounds.height))
            
            CGContextSetFillColorWithColor(ctx, self.color)
            CGContextFillPath(ctx)
            
        }
    }
    
}