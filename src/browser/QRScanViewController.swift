/*

`QRScanViewController` handles the scanning of QR codes for both tagging and searching videos.

It uses `AVCaptureMetadataOutput` internally for recognizing the QR code from a video feed.

*/

import UIKit
import AVFoundation

func avOrientationFromUiOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
    switch orientation {
    case .LandscapeLeft: return .LandscapeLeft
    case .LandscapeRight: return .LandscapeRight
    case .Portrait: return .Portrait
    case .PortraitUpsideDown: return .PortraitUpsideDown
    default: return .Portrait
    }
}

class QRScanViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var cancelButton: UIButton!
    
    var tapRecognizer: UITapGestureRecognizer?
    var captureSession: AVCaptureSession?
    var captureDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var highlightLayer: CALayer?
    
    var callback: (String -> ())?
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func viewDidLoad() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "focusTap:")
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.cancelButton.enabled = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        authorizeCamera(self.startCapture)
    }
    
    func startCapture(hasCamera: Bool) {
        do {
            if !hasCamera {
                throw UserError.permissionsMissing([.Camera])
            }
            
            let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
            let input = try AVCaptureDeviceInput(device: captureDevice)
            let output = AVCaptureMetadataOutput()
            
            let captureSession = AVCaptureSession()
            captureSession.sessionPreset = AVCaptureSessionPresetPhoto
            
            captureSession.addInput(input)
            captureSession.addOutput(output)
            
            output.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
            output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
            
            self.previewLayer?.removeFromSuperlayer()
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            previewLayer.frame = self.view.layer.bounds
            previewLayer.connection?.videoOrientation = avOrientationFromUiOrientation(UIApplication.sharedApplication().statusBarOrientation)
            self.view.layer.insertSublayer(previewLayer, atIndex: 0)
            
            captureSession.startRunning()
            
            self.previewLayer = previewLayer
            self.captureSession = captureSession
            self.captureDevice = captureDevice
            
        } catch {
            self.showErrorModal(error, title: NSLocalizedString("error_on_qr_capture", comment: "Error title shown when capturing a QR code fails.")) {
                self.dismissViewControllerAnimated(true, completion: nil)
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        self.captureSession?.stopRunning()
        self.highlightLayer?.removeFromSuperlayer()
        self.previewLayer?.removeFromSuperlayer()
        
        self.captureSession = nil
        self.previewLayer = nil
        self.highlightLayer = nil
        self.captureDevice = nil
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.previewLayer?.frame = self.view.layer.bounds
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        self.previewLayer?.connection?.videoOrientation = avOrientationFromUiOrientation(toInterfaceOrientation)
    }
    
    @IBAction func cancelButtonPressed(sender: UIButton) {
        self.captureSession?.stopRunning()
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func focusTap(recognizer: UITapGestureRecognizer) {
        guard let previewLayer = self.previewLayer, captureDevice = self.captureDevice else { return }
        
        let touchPoint = recognizer.locationInView(self.view)
        let videoPoint = previewLayer.captureDevicePointOfInterestForPoint(touchPoint)
        
        if captureDevice.focusPointOfInterestSupported && captureDevice.isFocusModeSupported(.AutoFocus) {
            do {
                try captureDevice.lockForConfiguration()
                
                captureDevice.focusPointOfInterest = videoPoint
                captureDevice.focusMode = .AutoFocus
                
                captureDevice.unlockForConfiguration()
            } catch {
            }
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        
        guard let previewLayer = self.previewLayer else { return }
        
        let codes = metadataObjects.flatMap { obj -> AVMetadataMachineReadableCodeObject? in
            if let code = obj as? AVMetadataMachineReadableCodeObject where code.type == AVMetadataObjectTypeQRCode {
                return code
            } else {
                return nil
            }
        }
    
        guard let code = codes.filter({ $0.stringValue != nil }).first else { return }
        guard let transformed = previewLayer.transformedMetadataObjectForMetadataObject(code) else { return }
        
        // Hack: Draw huge border to simulate focusing on one area
        let radius: CGFloat = 10000.0
        let padding: CGFloat = 40.0
        
        let layer = CALayer()
        layer.borderColor = hexCgColor(0x000000, alpha: 0.6)
        layer.borderWidth = radius
        layer.frame = transformed.bounds.insetBy(dx: -radius - padding, dy: -radius - padding)
        
        self.highlightLayer?.removeFromSuperlayer()
        self.highlightLayer = layer
        previewLayer.addSublayer(layer)
        
        self.cancelButton.enabled = false
        
        self.captureSession?.stopRunning()
        
        // String value guaranteed to exist, see above
        self.performSelector("returnResult:", withObject: code.stringValue!, afterDelay: 1.0)
        
    }

    func returnResult(code: String) {
        self.callback?(code)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

