import CoreGraphics

extension CGSize {
    
    // Return a size that fits inside `container` but maintains the original aspect ratio
    func fitInside(container: CGSize) -> CGSize {
        let ownAspect = self.width / self.height
        let containerAspect = container.width / container.height
        
        if ownAspect > containerAspect {
            return CGSize(width: container.width, height: container.width / ownAspect)
        } else {
            return CGSize(width: container.height * ownAspect, height: container.height)
        }
    }
    
    // Return the absolute value of the size
    func asPositive() -> CGSize {
        return CGSize(width: abs(self.width), height: abs(self.height))
    }

}
