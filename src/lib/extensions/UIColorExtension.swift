import Foundation
import UIKit

extension UIColor {
    // Usage: UIColor(hex: 0xFC0ACE)
    convenience init(hex: Int) {
        self.init(hex: hex, alpha: 1)
    }
    
    // Usage: UIColor(hex: 0xFC0ACE, alpha: 0.25)
    convenience init(hex: Int, alpha: Double) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: CGFloat(alpha))
    }
}
