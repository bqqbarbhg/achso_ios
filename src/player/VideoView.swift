import UIKit
import AVKit
import Foundation
import AVFoundation
import CoreGraphics

class VideoView: UIView {
    
    var callback: ((AnnotationEditEvent) -> ())?
    
    let avPlayerView: AVPlayerView
    var player: VideoPlayer?
    
    var selectedAnnotation: Annotation?
    
    typealias BoundLayer = (layer: CALayer, annotation: Annotation)
    var boundLayers = [BoundLayer]()
    var freeLayers = [CALayer]()
    
    required init?(coder aDecoder: NSCoder) {
        
        self.avPlayerView = AVPlayerView()

        super.init(coder: aDecoder)
        
        self.opaque = true
        self.avPlayerView.opaque = true
        self.avPlayerView.layer.masksToBounds = true
        
        self.backgroundColor = UIColor.blackColor()
        
        self.addSubview(self.avPlayerView)
    }
    
    override func layoutSubviews() {
        
        super.layoutSubviews()
        
        let containerSize = self.frame.size
        guard let videoSize = self.player?.videoSize else { return }
        
        let fittedSize = videoSize.fitInside(containerSize)

        let frame = self.frame.pinToCenter(fittedSize)
        self.avPlayerView.frame = frame
        
        layoutAnnotationLayers(animated: true)
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let position = Vector2(cgPoint: touch.locationInView(self.avPlayerView))
            let normalized = position / Vector2(cgSize: self.avPlayerView.frame.size)
            
            if normalized.x < 0.0 || normalized.y < 0.0 || normalized.x > 1.0 || normalized.y > 1.0 {
                // Ignore touches that _begin_ outside the video
                continue
            }
            
            self.callback?(AnnotationEditEvent(position: normalized, state: .Begin))
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let position = Vector2(cgPoint: touch.locationInView(self.avPlayerView))
            let normalized = position / Vector2(cgSize: self.avPlayerView.frame.size)
            self.callback?(AnnotationEditEvent(position: normalized, state: .Move))
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let position = Vector2(cgPoint: touch.locationInView(self.avPlayerView))
            let normalized = position / Vector2(cgSize: self.avPlayerView.frame.size)
            self.callback?(AnnotationEditEvent(position: normalized, state: .End))
        }
    }
    
    func attachPlayer(player: VideoPlayer) {
        avPlayerView.attachPlayer(player)
        self.player = player
        self.setNeedsLayout()
    }
    
    func allocateAnnotationLayer() -> CALayer {
        if let last = self.freeLayers.popLast() {
            self.avPlayerView.layer.addSublayer(last)
            return last
        }
        
        let layer = CALayer()
        layer.backgroundColor = nil
        layer.opaque = false
        
        self.avPlayerView.layer.addSublayer(layer)
        
        return layer
    }
    
    func freeAnnotationLayer(layer: CALayer) {
        layer.removeFromSuperlayer()
        self.freeLayers.append(layer)
    }
    
    func layoutAnnotationLayers(animated animated: Bool) {
        let bounds = self.avPlayerView.bounds
        
        let annotationSize: CGFloat = {
            if self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.Compact {
                return 60.0
            } else {
                return 80.0
            }
        }()
        
        let normalImage = AnnotationImage.getAnnotationImage(AnnotationParameters(size: annotationSize, isSelected: false))
        let selectedImage = AnnotationImage.getAnnotationImage(AnnotationParameters(size: annotationSize, isSelected: true))
        
        for (layer, annotation) in self.boundLayers {
            let image = annotation === self.selectedAnnotation ? selectedImage : normalImage
            
            if layer.contents !== image {
                layer.contents = image
            }
        }
        
        CATransaction.begin()
        
        if !animated {
            CATransaction.setDisableActions(true)
        }
        
        for (layer, annotation) in self.boundLayers {
            let center = CGPoint(
                x: bounds.origin.x + bounds.size.width * CGFloat(annotation.position.x),
                y: bounds.origin.y + bounds.size.height * CGFloat(annotation.position.y))
            
            layer.frame.origin = CGPoint(x: center.x - annotationSize / 2.0, y: center.y - annotationSize / 2.0)
            layer.frame.size = CGSize(width: annotationSize, height: annotationSize)
        }
        
        CATransaction.commit()
    }
    
    func showAnnotations(annotations: [Annotation], selected: Annotation?) {
        var newBoundLayers = [BoundLayer]()
        var newAnnotations = annotations
        
        self.selectedAnnotation = selected
        
        for layer in self.boundLayers {
            if let index = newAnnotations.indexOf({ $0 === layer.annotation }) {
                newAnnotations.removeAtIndex(index)
                newBoundLayers.append(layer)
            } else {
                freeAnnotationLayer(layer.layer)
            }
        }
        
        for annotation in newAnnotations {
            newBoundLayers.append((layer: allocateAnnotationLayer(), annotation: annotation))
        }
        
        self.boundLayers = newBoundLayers
        
        layoutAnnotationLayers(animated: false)
    }
}
