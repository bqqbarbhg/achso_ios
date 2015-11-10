import Foundation
import UIKit
import CoreGraphics

class AnnotationLayer: CALayer {

    var annotations: [Annotation] = []
    
    func createAnnotationGradient() -> CGGradient {
        
        struct GradientPoint {
            var location: CGFloat
            var color: CGColor
            
            init(location: CGFloat, color: CGColor) {
                self.location = location
                self.color = color
            }
        }
        
        let gradient = [
            GradientPoint(location: 0.37, color: rgbaCgColor(255,255,255, 0.0)),
            GradientPoint(location: 0.40, color: rgbaCgColor(255,255,255, 0.9)),
            GradientPoint(location: 0.45, color: rgbaCgColor(255,255,255, 0.9)),
            GradientPoint(location: 0.47, color: rgbaCgColor(68,153,136, 0.8)),
            GradientPoint(location: 0.53, color: rgbaCgColor(68,153,136, 0.4)),
            GradientPoint(location: 0.55, color: rgbaCgColor(68,153,136, 0.0)),
            GradientPoint(location: 0.56, color: rgbaCgColor(68,153,136, 0.0)),
            GradientPoint(location: 0.60, color: rgbaCgColor(85,204,153, 0.9)),
            GradientPoint(location: 0.62, color: rgbaCgColor(85,204,153, 0.9)),
            GradientPoint(location: 0.66, color: rgbaCgColor(85,204,153, 0.0)),
        ]
        
        // Do gradient in RGB for now
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let colors: NSArray = gradient.map { $0.color as AnyObject! }
        let locations: [CGFloat] = gradient.map { $0.location }
        
        return CGGradientCreateWithColors(colorSpace, colors, locations)!
    }
    
    override func drawInContext(ctx: CGContext) {
        let size = self.bounds.size
        let sizeVec = Vector2(cgSize: size)
    
        let annotationRadius = min(size.width, size.height) / 12.0
        
        for annotation in self.annotations {
            let absolutePosition = annotation.position * sizeVec
            
            // TODO: Create the gradient only once and stamp, preferably with the GPU
            let gradient = createAnnotationGradient()
            
            CGContextDrawRadialGradient(ctx, gradient, absolutePosition.cgPoint, 0.0, absolutePosition.cgPoint, annotationRadius, CGGradientDrawingOptions())
        }
    }
}

