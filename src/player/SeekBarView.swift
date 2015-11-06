import UIKit

class SeekBarView: UIView {

    let seekBarLayer: SeekBarLayer = SeekBarLayer()
    let playButtonLayer: PlayButtonLayer = PlayButtonLayer()
    
    var playButtonFrame: CGRect?
    var seekBarFrame: CGRect?
    var seekBarTouch: UITouch?
    
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
        
        self.layer.addSublayer(self.seekBarLayer)
        self.layer.addSublayer(self.playButtonLayer)
        
        let scale = UIScreen.mainScreen().scale
        self.seekBarLayer.contentsScale = scale
        self.playButtonLayer.contentsScale = scale
    }
    
    override func layoutSubviews() {
        self.layer.frame = self.frame
        
        let frame = CGRect(origin: CGPointZero, size: self.frame.size)
        
        let parts = frame.divide(50.0, fromEdge: CGRectEdge.MinXEdge)
        
        let leftSide = parts.slice
        let rest = parts.remainder
        
        let parts2 = rest.divide(40.0, fromEdge: CGRectEdge.MaxXEdge)
        
        let rightSide = parts2.slice
        
        self.playButtonFrame = leftSide
        self.seekBarFrame = parts2.remainder
        
        self.seekBarLayer.frame = self.seekBarFrame!
        self.playButtonLayer.frame = self.playButtonFrame!
        
        self.layer.setNeedsDisplay()
        self.seekBarLayer.setNeedsDisplay()
        self.playButtonLayer.setNeedsDisplay()
    }
    
    func isSeekBarTouch(touch: UITouch) -> Bool {
        if touch == self.seekBarTouch {
            return true
        }
        
        if let seekBarFrame = self.seekBarFrame {
            if touch.phase == .Began {
                let location = touch.locationInView(self)
                if seekBarFrame.contains(location) {
                    return true
                }
            }
        }
    
        return false
    }
    
    func interpretTouch(touch: UITouch) -> PlayerUserEvent? {
        
        let location = touch.locationInView(self)
        
        if let seekBarFrame = self.seekBarFrame {
            if isSeekBarTouch(touch) {
                
                if touch.phase == .Cancelled {
                    return .SeekCancel
                }
                
                self.seekBarTouch = touch
                
                let seekBarWidth = seekBarFrame.width - seekBarLayer.seekBallDiameter
                let seekBarStart = seekBarFrame.minX + seekBarLayer.seekBallDiameter / 2.0
                
                let relative = (location.x - seekBarStart) / seekBarWidth
                let clamped = Double(clamp(relative, minVal: 0.0, maxVal: 1.0))
                
                if touch.phase == .Ended {
                    return .SeekTo(clamped)
                } else {
                    return .SeekPreview(clamped)
                }
            }
        }
        
        if let playButtonFrame = self.playButtonFrame {
            if touch.phase == .Began && playButtonFrame.contains(location) {
                return .PlayPause
            }
        }
        
        return nil
    }
    
    func update(time: Double) {
        self.layer.setNeedsDisplay()
        
        self.seekBarLayer.seekBarPosition = CGFloat(time)
        self.seekBarLayer.setNeedsDisplay()
    }
    
    func updatePlaying(playing: Bool) {
        self.layer.setNeedsDisplay()
        
        self.playButtonLayer.isPlaying = playing
        self.playButtonLayer.setNeedsDisplay()
    }
}
