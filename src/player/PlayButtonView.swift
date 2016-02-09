/*

`PlayButtonView` is the play/pause button in the player view.
Most of the functionality is handled by the base class `UIControl`, so this handles mostly the state changing.

Uses PlayButtonLayer.swift for display.

*/

import UIKit

class PlayButtonView: UIControl {
    
    var callback: (()->())?
    
    // Layer

    var playButtonLayer: PlayButtonLayer {
        return self.layer as! PlayButtonLayer
    }
    override class func layerClass() -> AnyClass {
        return PlayButtonLayer.self
    }
    override func drawRect(rect: CGRect) {
        // Use PlayButtonLayer for drawing
    }
    override func layoutSubviews() {
        self.setNeedsDisplay()
    }
    
    // Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    func setup() {
        self.backgroundColor = nil
        self.opaque = false
        self.addTarget(self, action: "pressed:", forControlEvents: .TouchUpInside)
    }
    
    // Button mode
    
    enum ButtonMode {
        case Initial
        case Play
        case Pause
    }
    var buttonMode: ButtonMode = .Initial {
        didSet {
            if self.buttonMode == oldValue { return }
            
            let targetMorph: CGFloat = {
                switch self.buttonMode {
                case .Initial: return 0.0
                case .Play: return 0.0
                case .Pause: return 1.0
                }
            }()
            
            // Don't change mode on initial
            if self.buttonMode == .Initial {
                return
            }
            
            // No animation for the first set
            if oldValue == .Initial {
                self.playButtonLayer.pauseMorphDelta = targetMorph
                return
            }
            
            let animation = CABasicAnimation(keyPath: "pauseMorphDelta")
            animation.fromValue = self.playButtonLayer.pauseMorphDelta
            self.playButtonLayer.pauseMorphDelta = targetMorph
            animation.toValue = targetMorph
            animation.duration = 0.1
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            self.playButtonLayer.addAnimation(animation, forKey: "pauseMorphDelta")

        }
    }
    
    func setModeNoAniamtion(mode: ButtonMode) {
        // Set the mode to initial first to clear animation
        self.buttonMode = .Initial
        self.buttonMode = mode
    }
    
    func pressed(sender: UIControl) {
        callback?()
    }
    
    // Larger hit area
    
    override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
        let margin: CGFloat = 40.0
        let bounds = self.frame.insetBy(dx: -margin, dy: -margin)
        return bounds.contains(point)
    }
}
