import UIKit

func hexCgColor(hex: UInt32, alpha: CGFloat) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8)  & 0xFF) / 255.0
    let b = CGFloat((hex >> 0)  & 0xFF) / 255.0

    return UIColor(red: r, green: g, blue: b, alpha: alpha).CGColor
}
