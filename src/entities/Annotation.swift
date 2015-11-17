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
    
    init(annotationBase: AnnotationBase) {
        self.position = annotationBase.position
        self.text = annotationBase.text
        self.time = annotationBase.time
        self.author = annotationBase.author
    }
}
