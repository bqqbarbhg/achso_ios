import UIKit

extension CGColor {
    
    // Create a copy of the color with transparency of `alpha`
    func withAlpha(alpha: CGFloat) -> CGColor {
        return CGColorCreateCopyWithAlpha(self, alpha)!
    }
}

