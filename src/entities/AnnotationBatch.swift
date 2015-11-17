import Foundation

class AnnotationBatch {
    var time: Double
    var annotations: [Annotation]
    
    init(time: Double, annotations: [Annotation] = []) {
        self.time = time
        self.annotations = annotations
    }
}