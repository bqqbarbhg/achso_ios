import Foundation
import UIKit
import CoreGraphics

class AnnotationLayer: CALayer {

    var annotations: [Annotation] = []
    
    override func drawInContext(ctx: CGContext) {
        let size = self.bounds.size
        
        let annotationRadius = min(size.width, size.height) / 15.0
        let annotationSize = CGSize(width: annotationRadius * 2.0, height: annotationRadius * 2.0)
        
        let sizeVec = Vector2(cgSize: size)
        
        CGContextBeginPath(ctx)
        
        for annotation in self.annotations {
            let absolutePosition = annotation.position * sizeVec
            let rectPosition = absolutePosition - Vector2(xy: Float(annotationRadius))
            let rect = CGRect(origin: rectPosition.cgPoint, size: annotationSize)
            
            CGContextAddRect(ctx, rect)
        }
        
        CGContextSetFillColorWithColor(ctx, UIColor.redColor().CGColor)
        CGContextFillPath(ctx)
    }
}

