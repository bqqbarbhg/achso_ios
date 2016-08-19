/*

A single annotation object is defined here.

`AnnotationBase` is a memory-efficent storage of an Annotation, because it's a struct instead of a class.
However it's more convenient to work with classes in Swift as struct references don't really exist so
`Annotation` is used in general, while `AnnotationBase` is used only when required (ActiveVideoState.swift).

*/

import Foundation
import UIKit

struct AnnotationBase {
    var position: Vector2 = Vector2()
    var text: String = ""
    var time: Double = 0.0
    var author: User
    var createdTimestamp: NSDate
    
    
    init(annotation: Annotation) {
        self.position = annotation.position
        self.text = annotation.text
        self.time = annotation.time
        self.author = annotation.author
        self.createdTimestamp = annotation.createdTimestamp
    }
}

class Annotation {
    var position: Vector2 = Vector2()
    var text: String = ""
    var time: Double = 0.0
    var author: User = User()
    var createdTimestamp: NSDate = NSDate(timeIntervalSince1970: 0)
    let  materialDesignPalette: [Int] = [
                0xF44336,
                0xE91E63,
                0x9C27B0,
                0x673AB7,
                0x3F51B5,
                0x2196F3,
                0x03A9F4,
                0x00BCD4,
                0x009688,
                0x4CAF50,
                0x8BC34A,
                0xCDDC39,
                0xFFEB3B,
                0xFFC107,
                0xFF9800,
                0xFF5722,
                0x795548,
                0x9E9E9E,
                0x607D8B
        ]
 
    
    init() {
    }
    
    init(manifest: JSONObject) throws {
        let position: JSONObject = try manifest.castGet("position")
        self.position.x = try position.castGet("x")
        self.position.y = try position.castGet("y")
        
        self.text = try manifest.castGet("text")
        
        let timeInMs: Int = try manifest.castGet("time")
        self.time = Double(timeInMs) / 1000.0
        
        self.author = try User(manifest: manifest.castGet("author"))
        
        let timestamp = manifest["createdTimestamp"] as? String ?? ""
        self.createdTimestamp = iso8601DateFormatter.dateFromString(timestamp) ?? NSDate()
    }
    
    init(annotationBase: AnnotationBase) {
        self.position = annotationBase.position
        self.text = annotationBase.text
        self.time = annotationBase.time
        self.author = annotationBase.author
        self.createdTimestamp = annotationBase.createdTimestamp
    }
    
    func nameFowlerNollVo() -> UInt {
        let str = self.author.name.utf8
        let OffsetBasis: UInt = 2166136261
        let FNVPrime: UInt = 16777619
        
        var hash = OffsetBasis;
        
        for byte in str {
            hash ^= UInt(byte)
            hash = hash &* FNVPrime
        }
        
        return hash;
    }
    
    func calculateMarkerColor() -> UIColor {
        let hash = self.nameFowlerNollVo()
        let hashSigned = Int32(truncatingBitPattern: hash)
        var index = hashSigned % Int32((self.materialDesignPalette.count - 1))
        
        if index < 0 {
            index = index * -1
        }
        
        guard let colorNumber : Int = materialDesignPalette[Int(index)] else {
            return UIColor.blackColor()
        }
        
        return UIColor(hex: colorNumber)
    }
    
    func toManifest() -> JSONObject {
        return [
            "position": [
                "x": position.x,
                "y": position.y,
            ] as JSONObject,
            "text": text,
            "time": Int(time * 1000),
            "author": author.toManifest(),
            "createdTimestamp": iso8601DateFormatter.stringFromDate(self.createdTimestamp),
        ]
    }
    
}

func ==(a: Annotation, b: Annotation) -> Bool {
    return a.position == b.position && a.time == b.time && a.text == b.text && a.createdTimestamp == b.createdTimestamp
}