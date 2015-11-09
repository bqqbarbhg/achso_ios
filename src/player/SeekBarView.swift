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
    override func layoutSubviews() {
        self.setNeedsDisplay()
    }
    
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
        
        // Evaluate location in bar accounting the width of the seek ball
        let seekBarWidth = self.frame.width - seekBarLayer.seekBallDiameter
        let seekBarStart = seekBarLayer.seekBallDiameter / 2.0
        let relative = (location.x - seekBarStart) / seekBarWidth
        
        let clamped = Double(clamp(relative, minVal: 0.0, maxVal: 1.0))
        
        if touch.phase == .Ended {
            callback?(seekEvent: SeekEvent.SeekTo(time: clamped))
        } else {
            callback?(seekEvent: SeekEvent.Preview(time: clamped))
        }
    }
}
