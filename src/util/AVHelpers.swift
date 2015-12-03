import AVKit
import AVFoundation

func getThumbnailFromVideo(assetUrl: NSURL, relativeTime: Double = 0.3) throws -> CGImage {
    let asset = AVAsset(URL: assetUrl)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    let time = CMTime(seconds: relativeTime * asset.duration.seconds, preferredTimescale: 1000)
    return try imageGenerator.copyCGImageAtTime(time, actualTime: nil)
}

func saveThumbnailFromVideo(assetUrl: NSURL, outputUrl: NSURL, relativeTime: Double = 0.3, quality: CGFloat = 0.8) throws {
    let thumbnailImage = UIImage(CGImage: try getThumbnailFromVideo(assetUrl, relativeTime: relativeTime))
    
    let jpgData = try UIImageJPEGRepresentation(thumbnailImage, quality).unwrap()
    try jpgData.writeToURL(outputUrl, options: .DataWritingAtomic)
}
