import AVFoundation
import AssetsLibrary

func authorizeCamera(callback: Bool -> ()) {
    let cameraMediaType = AVMediaTypeVideo
    let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(cameraMediaType)
    
    switch cameraAuthorizationStatus {
        
    case .Authorized:
        callback(true)
        
    case .Restricted, .Denied:
        callback(false)
        
    case .NotDetermined:
        AVCaptureDevice.requestAccessForMediaType(cameraMediaType, completionHandler: callback)
    }
}
