import Foundation
import UIKit

struct Vector2 {
    var x: Float
    var y: Float
    
    init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
    init(xy: Float) {
        self.init(x: xy, y: xy)
    }
    init() {
        self.init(x: 0.0, y: 0.0)
    }
    init(cgPoint: CGPoint) {
        self.init(x: Float(cgPoint.x), y: Float(cgPoint.y))
    }
    init(cgSize: CGSize) {
        self.init(x: Float(cgSize.width), y: Float(cgSize.height))
    }
    
    var cgPoint: CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    var lengthSquared: Float {
        return x*x + y*y;
    }
    
    func clampBetween(min: Vector2, and max: Vector2) -> Vector2 {
        return Vector2(x: clamp(self.x, minVal: min.x, maxVal: max.x), y: clamp(self.y, minVal: min.y, maxVal: max.y))
    }
}

func +(a: Vector2, b: Vector2) -> Vector2 {
    return Vector2(x: a.x + b.x, y: a.y + b.y)
}

func -(a: Vector2, b: Vector2) -> Vector2 {
    return Vector2(x: a.x - b.x, y: a.y - b.y)
}

func *(a: Vector2, b: Vector2) -> Vector2 {
    return Vector2(x: a.x * b.x, y: a.y * b.y)
}

func /(a: Vector2, b: Vector2) -> Vector2 {
    return Vector2(x: a.x / b.x, y: a.y / b.y)
}

func /(a: Vector2, b: Float) -> Vector2 {
    return Vector2(x: a.x / b, y: a.y / b)
}
