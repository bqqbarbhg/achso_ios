import AVKit
import AVFoundation

func getThumbnailFromVideo(assetUrl: NSURL, relativeTime: Double = 0.3) throws -> CGImage {
    let asset = AVAsset(URL: assetUrl)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    let time = CMTime(seconds: relativeTime * asset.duration.seconds, preferredTimescale: 1000)
    return try imageGenerator.copyCGImageAtTime(time, actualTime: nil)
}

func saveThumbnailFromVideo(assetUrl: NSURL, filename: String, relativeTime: Double = 0.3, quality: CGFloat = 0.8) throws -> NSURL {
    let thumbnailImage = UIImage(CGImage: try getThumbnailFromVideo(assetUrl, relativeTime: relativeTime))
    
    let fileManager = NSFileManager.defaultManager()
    let documentsUrl = try fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[safe: 0].unwrap()
    let thumbnailsUrl = documentsUrl.URLByAppendingPathComponent("thumbnails", isDirectory: true)
    
    if !fileManager.fileExistsAtPath(try thumbnailsUrl.path.unwrap()) {
        try fileManager.createDirectoryAtURL(thumbnailsUrl, withIntermediateDirectories: true, attributes: nil)
    }
    
    let fileUrl = thumbnailsUrl.URLByAppendingPathComponent(filename)
    
    let jpgData = try UIImageJPEGRepresentation(thumbnailImage, quality).unwrap()
    try jpgData.writeToURL(fileUrl, options: .DataWritingAtomic)
    
    return fileUrl
}
