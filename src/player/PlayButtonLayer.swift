/*

`PlayButtonLayer` draws the morphing play/pause button. See PlayButtonView.swift.

*/

import UIKit
import CoreGraphics

class PlayButtonLayer: CALayer {
    
    // Parameters
    var pauseMorphDelta: CGFloat = 0.0 {
        didSet { self.setNeedsDisplay() }
    }
    var borderPadding: CGFloat = 0.0
    
    // Visual measueres
    var pauseThickness: CGFloat = 0.8
    
    // Visual colors
    var color: CGColor = hexCgColor(0xEEEEEE, alpha: 1.0)
    
    override class func needsDisplayForKey(key: String) -> Bool {
        switch key {
        case "pauseMorphDelta": return true
        default: return super.needsDisplayForKey(key)
        }
    }
    
    override func drawInContext(ctx: CGContext) {
        super.drawInContext(ctx)
        
        let bounds = CGRect(origin: CGPointZero, size: self.frame.size)
            .insetBy(dx: borderPadding, dy: borderPadding)
        
        CGContextClearRect(ctx, bounds)
        
        let pauseWidth = round(bounds.width * (self.pauseThickness / 2.0))
        
        if pauseMorphDelta <= 0.0 {
            // Draw clean play triangle
            
            CGContextBeginPath(ctx)
            
            CGContextMoveToPoint(ctx, bounds.maxX, bounds.midY)
            CGContextAddLineToPoint(ctx, bounds.minX, bounds.maxY)
            CGContextAddLineToPoint(ctx, bounds.minX, bounds.minY)
            
            CGContextSetFillColorWithColor(ctx, self.color)
            CGContextFillPath(ctx)
            
        } else if pauseMorphDelta >= 1.0 {
            // Draw clean pause double rectangle

            CGContextBeginPath(ctx)

            // Left rectangle
            CGContextAddRect(ctx, CGRect(x: bounds.minX, y: bounds.minY,
                width: pauseWidth, height: bounds.height))
            
            // Right rectangle
            CGContextAddRect(ctx, CGRect(x: bounds.maxX - pauseWidth, y: bounds.minY,
                width: pauseWidth, height: bounds.height))
            
            CGContextSetFillColorWithColor(ctx, self.color)
            CGContextFillPath(ctx)
            
        } else {
            // Draw two isoceles trapezoids morphing between play and pause.
            // See http://i.imgur.com/KEzqNF4.png
            
            // X-intersections on begin, end and widening gap
            let halfGap = pauseMorphDelta * 0.5 * (1.0 - (pauseWidth * 2.0) / bounds.width)
            let xs = [0.0, 0.5 - halfGap, 0.5 + halfGap, 1.0]
            
            // Evaluate the line at the X-coordinates to get the Y-coordinates
            let endCap = 0.5 * (1.0 - pauseMorphDelta)
            let ys = xs.map { $0 * endCap }
            
            // Transform points to CG space and mirror the Y-coordinates to get the lower line
            let cg_x = xs.map { $0 * bounds.maxX + (1.0 - $0) * bounds.minX }
            let cg_y_top = ys.map { $0 * bounds.maxY + (1.0 - $0) * bounds.minY }
            let cg_y_bottom = ys.map { $0 * bounds.minY + (1.0 - $0) * bounds.maxY }
            
            CGContextBeginPath(ctx)
            
            // Left trapezoid
            CGContextMoveToPoint(ctx, cg_x[0], cg_y_top[0])
            CGContextAddLineToPoint(ctx, cg_x[1], cg_y_top[1])
            CGContextAddLineToPoint(ctx, cg_x[1], cg_y_bottom[1])
            CGContextAddLineToPoint(ctx, cg_x[0], cg_y_bottom[0])
            
            // Right trapezoid
            CGContextMoveToPoint(ctx, cg_x[2], cg_y_top[2])
            CGContextAddLineToPoint(ctx, cg_x[3], cg_y_top[3])
            CGContextAddLineToPoint(ctx, cg_x[3], cg_y_bottom[3])
            CGContextAddLineToPoint(ctx, cg_x[2], cg_y_bottom[2])
            
            CGContextSetFillColorWithColor(ctx, self.color)
            CGContextFillPath(ctx)
        }
    }
    
}
