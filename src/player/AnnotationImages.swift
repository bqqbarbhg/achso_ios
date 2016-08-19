/*

Manages the annotation ring graphics.

Request an image by parameters with `getAnnotationImage`.
It renders a new image using gradients.

*/

import UIKit

struct AnnotationParameters: Equatable, Hashable {
    var size: CGFloat
    var isSelected: Bool
    var outerRingColor: UInt32
    
    var hashValue: Int {
        return size.hashValue ^ isSelected.hashValue
    }
    
    init(size: CGFloat, outerRingColor: UInt32,  isSelected: Bool) {
        self.size = size
        self.isSelected = isSelected
        self.outerRingColor = outerRingColor
    }
}

func ==(lhs: AnnotationParameters, rhs: AnnotationParameters) -> Bool {
    return lhs.size == rhs.size && lhs.isSelected == rhs.isSelected
}

class AnnotationImage {
    
    static func createAnnotationImage(params: AnnotationParameters) -> CGImage {
        
        let size = CGSize(width: params.size, height: params.size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let ctx = UIGraphicsGetCurrentContext()
        
        // Leave some space so that the antialias doesn't clip
        let padding: CGFloat = 2.0
        let position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        let circleScale = params.size * 0.5 - padding
        
        let innerGlowGradient = makeGradient([
            GradientPoint(location: 0.0, color: hexCgColor(0x88FFFF, alpha: 0.8)),
            GradientPoint(location: 1.0, color: hexCgColor(0x00FFFF, alpha: 0.0)),
        ])
        let innerGlowLength: CGFloat = 0.3
        
        typealias Ring = (radius: CGFloat, thickness: CGFloat, color: CGColor)
        
        let innerRing = Ring(radius: 0.5, thickness: 0.1, color: hexCgColor(0xFFFFFF, alpha: 1.0))
        
        let outerRingColor: CGColor = {
            if params.isSelected {
                return hexCgColor(params.outerRingColor, alpha: 1.0)
            } else {
                return hexCgColor(params.outerRingColor, alpha: 0.8)
            }
        }()
        
        let outerRing = Ring(radius: 0.8, thickness: 0.1, color: outerRingColor)
        
        func drawRing(ring: Ring) {
            CGContextBeginPath(ctx)
            CGContextAddArc(ctx, position.x, position.y, ring.radius * circleScale, 0.0, CGFloat(2.0 * M_PI), 0)
            
            CGContextSetStrokeColorWithColor(ctx, ring.color)
            CGContextSetLineWidth(ctx, ring.thickness * circleScale)
            CGContextStrokePath(ctx)
        }
        
        CGContextDrawRadialGradient(ctx, innerGlowGradient,
            position, innerRing.radius * circleScale,
            position, (innerRing.radius + innerGlowLength) * circleScale,
            CGGradientDrawingOptions())

        
        drawRing(innerRing)
        drawRing(outerRing)
        
        return UIGraphicsGetImageFromCurrentImageContext().CGImage!
    }
    
    static var annotationImageMap = [AnnotationParameters: CGImage]()
    
    static func getAnnotationImage(params: AnnotationParameters) -> CGImage {
        let image = createAnnotationImage(params)
        annotationImageMap[params] = image
        
        return image
    }
}

