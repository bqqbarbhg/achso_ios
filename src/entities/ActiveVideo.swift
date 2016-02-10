/*

`ActiveVideo` is an video that is currently played or edited, in a better data structure.

Modifications to the video can be solidified with `toVideo()`

Annotations are separated to batches by time, so that ones that are displayed at once are contained in one batch.
This is the data structure that is used with playing and editing.

*/

import Foundation

class ActiveVideo {
    
    var video: Video
    var duration: Double = 0.0
    var batches: [AnnotationBatch] = []
    var resolution: Vector2 = Vector2()
    var annotationRadius: Float = 0.15
    var user: User
    
    init(video: Video, user: User) {
        self.video = video
        self.user = user
        
        let importEpsilon = 0.001
        for annotation in video.annotations {
            let match = self.closestBatch(annotation.time)
            if let batch = match.batch where match.dist <= importEpsilon {
                batch.annotations.append(annotation)
            } else {
                self.batches.append(AnnotationBatch(time: annotation.time, annotations: [annotation]))
            }
        }
    }
    
    func batchBetween(start: Double, end: Double) -> AnnotationBatch? {
        var minBatch: AnnotationBatch? = nil

        for batch in batches {
            if batch.time < start || batch.time > end {
                continue
            }
            
            if let other = minBatch {
                if batch.time < other.time {
                    minBatch = batch
                }
            } else {
                minBatch = batch
            }
        }
        
        return minBatch
    }
    
    func closestBatch(time: Double) -> (batch: AnnotationBatch?, dist: Double) {
        var minDist = Double.infinity
        var minBatch: AnnotationBatch? = nil
        
        for batch in self.batches {
            let dist = abs(batch.time - time)
            if dist < minDist {
                minDist = dist
                minBatch = batch
            }
        }
        
        return (batch: minBatch, dist: minDist)
    }
    
    func closestBatch(time: Double, minimumDistance: Double) -> AnnotationBatch? {
        let match = self.closestBatch(time)
        if let batch = match.batch where match.dist <= minimumDistance {
            return batch
        }
        return nil
    }
    
    func findOrCreateBatch(time: Double) -> AnnotationBatch {
        let epsilon = 0.001
        let match = closestBatch(time)
        if let batch = match.batch where match.dist <= epsilon {
            return batch
        } else {
            let batch = AnnotationBatch(time: time)
            self.batches.append(batch)
            return batch
        }
    }
    
    func findAnnotationAt(position: Vector2, inBatch batch: AnnotationBatch) -> Annotation? {
        var minDiff = annotationRadius * annotationRadius
        var minAnnotation: Annotation? = nil

        for annotation in batch.annotations {
            let diff = ((annotation.position - position) * self.resolution).lengthSquared
            if diff < minDiff {
                minDiff = diff
                minAnnotation = annotation
            }
        }
        
        return minAnnotation
    }
    
    func findOrCreateAnnotationAt(position: Vector2, inBatch batch: AnnotationBatch) -> (annotation: Annotation, wasCreated: Bool) {
        
        if let annotation = findAnnotationAt(position, inBatch: batch) {
            return (annotation: annotation, wasCreated: false)
        } else {
            let annotation = Annotation()
            annotation.position = position
            annotation.time = batch.time
            annotation.author = self.user
            annotation.createdTimestamp = NSDate()
            
            batch.annotations.append(annotation)
            return (annotation: annotation, wasCreated: true)
        }
    }
    
    func deleteAnnotation(annotation: Annotation) {
        for (batchIndex, batch) in self.batches.enumerate() {
            if let index = batch.annotations.indexOf({ $0 === annotation }) {
                batch.annotations.removeAtIndex(index)
                
                if batch.annotations.count == 0 {
                    self.batches.removeAtIndex(batchIndex)
                }
                return
            }
        }
    }
    
    func saveState() -> ActiveVideoState {
        return ActiveVideoState(batches: self.batches)
    }
    func restoreState(state: ActiveVideoState) {
        self.batches = state.batches
    }
    
    func toVideo() -> Video {
        let video = Video(copyFrom: self.video)
        video.annotations = self.batches.flatMap({ $0.annotations })
        return video
    }
}
