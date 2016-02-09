/*

`AnnotationBatch` is a batch of Annotations in a single time point.
See ActiveVideo.swift and Annotation.swift.

*/

import Foundation

class AnnotationBatch {
    var time: Double
    var annotations: [Annotation]
    
    init(time: Double, annotations: [Annotation] = []) {
        self.time = time
        self.annotations = annotations
    }
}
