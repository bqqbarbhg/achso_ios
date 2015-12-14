import UIKit

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