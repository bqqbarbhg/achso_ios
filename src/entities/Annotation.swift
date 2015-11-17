import Foundation

struct AnnotationBase {
    var position: Vector2 = Vector2()
    var text: String = ""
    var time: Double = 0.0
    var author: User?
    
    init(annotation: Annotation) {
        self.position = annotation.position
        self.text = annotation.text
        self.time = annotation.time
        self.author = annotation.author
    }
}

class Annotation {
    var position: Vector2 = Vector2()
    var text: String = ""
    var time: Double = 0.0
    var author: User?
    
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
    }
    
    init(annotationBase: AnnotationBase) {
        self.position = annotationBase.position
        self.text = annotationBase.text
        self.time = annotationBase.time
        self.author = annotationBase.author
    }
    
    func toManifest() -> JSONObject {
        return [
            "position": [
                "x": position.x,
                "y": position.y,
            ] as JSONObject,
            "text": text,
            "time": Int(time * 1000),
            "author": author?.toManifest() ?? JSONObject(),
        ]
    }
}
