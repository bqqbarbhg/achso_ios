import UIKit

func rgbaCgColor(r: Int, _ g: Int, _ b: Int, _ alpha: CGFloat) -> CGColor {
    return UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: alpha).CGColor
}

func hexCgColor(hex: UInt32, alpha: CGFloat) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8)  & 0xFF) / 255.0
    let b = CGFloat((hex >> 0)  & 0xFF) / 255.0

    return UIColor(red: r, green: g, blue: b, alpha: alpha).CGColor
}
