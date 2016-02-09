/*

`SeekAnnotationLayer` is a `CALayer` responsible for drawing the annotation markers on the seek bar.

See SeekBarView.swift.

*/

import UIKit

class SeekAnnotationLayer: CALayer {
    
    private var prevAnnotationTimes: [Double] = []
    
    var annotationTimes: [Double] = [] {
        didSet {
            // If all the elements are roughly the same no need to redraw
            var allSame = true
            if self.prevAnnotationTimes.count == self.annotationTimes.count {
                let epsilon = 0.001
                for (prev, new) in zip(self.prevAnnotationTimes.sort(), self.annotationTimes.sort()) {
                    if abs(prev - new) > epsilon {
                        allSame = false
                        break
                    }
                }
            } else {
                allSame = false
            }

            if allSame {
                // Do nothing, don't update prevAnnotationTimes so it can't slide without redraw
            } else {
                self.setNeedsDisplay()
                self.prevAnnotationTimes = self.annotationTimes
            }
        }
    }
    
    // Visual measures
    var markerDiamater: CGFloat = 7.0
    var markerThickness: CGFloat = 1.0
    var sidePadding: CGFloat = 0.0
    
    var requiredSidePadding: CGFloat {
        return self.markerDiamater + self.markerThickness
    }
    
    // Visual colors
    var color: CGColor = hexCgColor(0xFF3333, alpha: 1.0)
    
    override func drawInContext(ctx: CGContext) {
        // Fit the bar so that the ball has enough space on both sides without clipping
        let bounds = CGRect(x: self.sidePadding, y: 0.0,
            width: self.frame.width - self.sidePadding * 2.0,
            height: self.frame.height)
        
        let middle = bounds.midY
        
        for time in annotationTimes {
            let pos = bounds.minX + bounds.width * CGFloat(time)
            
            CGContextBeginPath(ctx)
            CGContextAddArc(ctx, pos, middle, self.markerDiamater / 2.0, 0.0, CGFloat(M_PI * 2.0), 1)
            CGContextSetStrokeColorWithColor(ctx, self.color)
            CGContextSetLineWidth(ctx, self.markerThickness)
            CGContextStrokePath(ctx)
        }
    }
    
}
