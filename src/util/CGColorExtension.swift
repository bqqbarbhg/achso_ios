import UIKit

extension CGColor {
    func withAlpha(alpha: CGFloat) -> CGColor {
        return CGColorCreateCopyWithAlpha(self, alpha)!
    }
}

