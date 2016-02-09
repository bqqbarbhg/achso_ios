/*

Implements SDWebImageManagerDelegate that crops downloaded images into 4:3 aspect ratio.

*/

import SDWebImage

class ImageLoader: NSObject, SDWebImageManagerDelegate {
    static var instance = ImageLoader()
    
    func imageManager(imageManager: SDWebImageManager!, transformDownloadedImage image: UIImage!, withURL imageURL: NSURL!) -> UIImage! {
        
        let aspectSize = CGSize(width: 4.0, height: 3.0)
        let fittedSize = aspectSize.fitInside(image.size)
        let rect = CGRect(origin: CGPointZero, size: image.size).pinToCenter(fittedSize)
        
        return UIImage(CGImage: CGImageCreateWithImageInRect(image.CGImage, rect)!)
    }
    
}
