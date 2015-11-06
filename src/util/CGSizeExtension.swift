import CoreGraphics

extension CGSize {
    
    func fitInside(container: CGSize) -> CGSize {
        let ownAspect = self.width / self.height
        let containerAspect = container.width / container.height
        
        if ownAspect > containerAspect {
            return CGSize(width: container.width, height: container.width / ownAspect)
        } else {
            return CGSize(width: container.height * ownAspect, height: container.height)
        }
    }
    
    func asPositive() -> CGSize {
        return CGSize(width: abs(self.width), height: abs(self.height))
    }

}
