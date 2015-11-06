import UIKit

extension CGRect {
    
    func pinToCenter(size: CGSize) -> CGRect {
        let selfCenter = CGPoint(
            x: self.origin.x + self.size.width / 2.0,
            y: self.origin.y + self.size.height / 2.0)
        
        let origin = CGPoint(
            x: selfCenter.x - size.width / 2.0,
            y: selfCenter.y - size.height / 2.0)
        
        return CGRect(origin: origin, size: size)
    }
    
}
