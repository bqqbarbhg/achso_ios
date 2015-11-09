import UIKit

class SeekBarView: UIControl {
    
    enum SeekEvent {
        case Preview(time: Double)
        case SeekTo(time: Double)
        case Cancel
    }
    
    var callback: ((seekEvent: SeekEvent) -> ())?
    
    // Layer
    
    var seekBarLayer: SeekBarLayer {
        return self.layer as! SeekBarLayer
    }
    override class func layerClass() -> AnyClass {
        return SeekBarLayer.self
    }
    override func drawRect(rect: CGRect) {
        // Use SeekBarLayer for drawing
    }
    
    let seekAnnotationLayer = SeekAnnotationLayer()
    
    var sidePadding: CGFloat = 0.0
    
    // Initialization
    
    init() {
        super.init(frame: CGRectZero)
        self.setup()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    func setup() {
        self.backgroundColor = nil
        self.opaque = false
        self.seekAnnotationLayer.contentsScale = self.layer.contentsScale
        self.layer.addSublayer(self.seekAnnotationLayer)
        
        // Make sure the layers have the same side padding
        self.sidePadding = max(seekBarLayer.requiredSidePadding, seekAnnotationLayer.requiredSidePadding)
        self.seekBarLayer.sidePadding = self.sidePadding
        self.seekAnnotationLayer.sidePadding = self.sidePadding
        
        // TEMP
        self.seekAnnotationLayer.annotationTimes = [0.0, 0.2, 0.3, 0.5, 1.0]
    }

    // Seek position
    
    var seekBarPositionPercentage: Double {
        get {
            return Double(seekBarLayer.seekBarPositionRelative)
        }
        set {
            seekBarLayer.seekBarPositionRelative = CGFloat(newValue)
        }
    }

    override func layoutSublayersOfLayer(layer: CALayer) {
        super.layoutSublayersOfLayer(layer)
        
        if layer == self.seekBarLayer {
            self.seekAnnotationLayer.frame = layer.bounds
            self.seekAnnotationLayer.setNeedsDisplay()
            self.seekBarLayer.setNeedsDisplay()
        }
    }
    
    // Touch tracking
    
    override func beginTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
        trackTouch(touch)
        return true // Always continue tracking
    }
    
    override func continueTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
        trackTouch(touch)
        return true // Always continue tracking
    }
    
    override func endTrackingWithTouch(touch: UITouch?, withEvent event: UIEvent?) {
        if let touch = touch {
            trackTouch(touch)
        } else {
            callback?(seekEvent: .Cancel)
        }
    }
    
    override func cancelTrackingWithEvent(event: UIEvent?) {
        callback?(seekEvent: .Cancel)
    }
    
    func trackTouch(touch: UITouch) {
        if touch.phase == .Cancelled {
            callback?(seekEvent: .Cancel)
            return
        }
        
        let location = touch.locationInView(self)
        
        // Evaluate location in bar accounting the padding in the display
        let seekBarWidth = self.frame.width - self.sidePadding * 2.0
        let seekBarStart = self.sidePadding
        let relative = (location.x - seekBarStart) / seekBarWidth
        
        let clamped = Double(clamp(relative, minVal: 0.0, maxVal: 1.0))
        
        if touch.phase == .Ended {
            callback?(seekEvent: SeekEvent.SeekTo(time: clamped))
        } else {
            callback?(seekEvent: SeekEvent.Preview(time: clamped))
        }
    }
}
