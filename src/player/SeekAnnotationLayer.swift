/*

`SeekAnnotationLayer` is a `CALayer` responsible for drawing the annotation markers on the seek bar.

See SeekBarView.swift.

*/

import UIKit

class SeekAnnotationLayer: CALayer {
    
    private var prevSeekBarAnnotations: [Annotation] = []
    
    var videoLength: Double = 1.0
    
    var seekBarAnnotations: [Annotation] = [] {
        didSet {
            // If all the elements are roughly the same no need to redraw
            var allSame = true
            if self.prevSeekBarAnnotations.count == self.seekBarAnnotations.count {
                let epsilon = 0.001
                for (prev, new) in zip(self.prevSeekBarAnnotations.sort{$0.0.time < $0.1.time}, self.seekBarAnnotations.sort{$0.0.time < $0.1.time}) {
                    if abs(prev.time - new.time) > epsilon {
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
                self.prevSeekBarAnnotations = self.seekBarAnnotations
            }
        }
    }
    
    // Visual measures
    var markerDiamater: CGFloat = 7.0
    var markerThickness: CGFloat = 2.0
    var sidePadding: CGFloat = 0.0
    
    var requiredSidePadding: CGFloat {
        return self.markerDiamater + self.markerThickness
    }
    
    override func drawInContext(ctx: CGContext) {
        // Fit the bar so that the ball has enough space on both sides without clipping
        let bounds = CGRect(x: self.sidePadding, y: 0.0,
            width: self.frame.width - self.sidePadding * 2.0,
            height: self.frame.height)
        
        let middle = bounds.midY
        
        for annotation in seekBarAnnotations {
            let pos = bounds.minX + bounds.width * CGFloat(annotation.time / videoLength)
            let color = hexCgColor(annotation.calculateMarkerColor(), alpha: 1.0)
            
            CGContextBeginPath(ctx)
            CGContextAddArc(ctx, pos, middle, self.markerDiamater / 2.0, 0.0, CGFloat(M_PI * 2.0), 1)
            CGContextSetStrokeColorWithColor(ctx, color)
            CGContextSetLineWidth(ctx, self.markerThickness)
            CGContextStrokePath(ctx)
        }
    }
    
}
