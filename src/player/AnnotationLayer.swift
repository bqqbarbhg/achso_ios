import Foundation
import UIKit
import CoreGraphics

class AnnotationLayer: CALayer {

    var selectedAnnotation: Annotation?
    var annotations: [Annotation] = []
    
    struct GradientPoint {
        var location: CGFloat
        var color: CGColor
        
        init(location: CGFloat, color: CGColor) {
            self.location = location
            self.color = color
        }
    }

    func makeGradient(points: [GradientPoint]) -> CGGradient {
        // Do gradient in RGB for now
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let colors: NSArray = points.map { $0.color as AnyObject! }
        let locations: [CGFloat] = points.map { $0.location }
        
        return CGGradientCreateWithColors(colorSpace, colors, locations)!
    }
    
    func createAnnotationGradient() -> CGGradient {
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
        
        return makeGradient(gradient)
    }
    
    func createSelectedAnnotationGradient() -> CGGradient {
        let gradient = [
            GradientPoint(location: 0.37, color: rgbaCgColor(255,255,255, 0.0)),
            GradientPoint(location: 0.40, color: rgbaCgColor(255,255,255, 0.9)),
            GradientPoint(location: 0.45, color: rgbaCgColor(255,255,255, 0.9)),
            GradientPoint(location: 0.47, color: rgbaCgColor(68,153,136, 0.8)),
            GradientPoint(location: 0.53, color: rgbaCgColor(68,153,136, 0.4)),
            GradientPoint(location: 0.55, color: rgbaCgColor(68,153,136, 0.0)),
            GradientPoint(location: 0.56, color: rgbaCgColor(255,255,255, 0.0)),
            GradientPoint(location: 0.57, color: rgbaCgColor(255,255,255, 0.9)),
            GradientPoint(location: 0.66, color: rgbaCgColor(255,255,255, 0.9)),
            GradientPoint(location: 0.67, color: rgbaCgColor(255,255,255, 0.4)),
            GradientPoint(location: 0.68, color: rgbaCgColor(0,0,0, 0.3)),
            GradientPoint(location: 0.8, color: rgbaCgColor(0,0,0, 0.0)),
        ]
        
        return makeGradient(gradient)
    }
    
    override func drawInContext(ctx: CGContext) {
        let size = self.bounds.size
        let sizeVec = Vector2(cgSize: size)
    
        let annotationRadius = min(size.width, size.height) / 12.0
        
        for annotation in self.annotations {
            let absolutePosition = annotation.position * sizeVec
            
            // TODO: Create the gradient only once and stamp, preferably with the GPU
            let gradient: CGGradient = {
                if annotation === self.selectedAnnotation {
                    return createSelectedAnnotationGradient()
                } else {
                    return createAnnotationGradient()
                }
            }()
            
            CGContextDrawRadialGradient(ctx, gradient, absolutePosition.cgPoint, 0.0, absolutePosition.cgPoint, annotationRadius, CGGradientDrawingOptions())
        }
    }
}

