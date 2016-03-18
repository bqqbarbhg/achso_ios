/*

This implements the logic for the player.

This is separated to 4 states: `Playing`, `ManualPause`, `AnnotationPause`, `AnnotationEdit`.
The states implement `PlayerHandler` which has a response to 5 different events `start`, `timeUpdate`, `userPlay`, `userSeek`, `annotationEdit`.
This defines a matrix of responses to events which is very predictable.

If some state has no response for an event it may switch into another and delegate the event to that.

This file also contains the logic for editing the annotations in the `AnnotationEditHandler.annotationEdit` function.

*/

import Foundation

enum PlayerState {
    case Playing
    case ManualPause
    case AnnotationPause
    case AnnotationEdit
}

struct AnnotationEditEvent {
    enum State {
        case Begin
        case Move
        case End
    }
    
    var position: Vector2
    var state: State
    
    init(position: Vector2, state: State) {
        self.position = position
        self.state = state
    }
}

protocol PlayerHandler {
    func start(c: PlayerController)
    func timeUpdate(c: PlayerController, time: Double, lastTime: Double)
    func userPlay(c: PlayerController)
    func userSeek(c: PlayerController, time: Double, final: Bool)
    func annotationEdit(c: PlayerController, event: AnnotationEditEvent)
}

class PlayingHandler: PlayerHandler {
    
    func start(c: PlayerController) {
        c.player.play()
        c.ignoreBatch = c.batch
        c.batch = nil
    }
    
    func timeUpdate(c: PlayerController, time: Double, lastTime: Double) {
        // TODO: Next time?
        
        let delta = time - lastTime
        let nextTime = time + delta
        
        if let batch = c.activeVideo.batchBetween(lastTime, end: nextTime) {
            if batch !== c.ignoreBatch {
                c.batch = batch
                c.switchState(.AnnotationPause)
                c.seekBarPosition = batch.time
            }
        } else {
            c.seekBarPosition = time
        }
    }
    
    func userPlay(c: PlayerController) {
        c.switchState(.ManualPause)
    }
    
    func userSeek(c: PlayerController, time: Double, final: Bool) {
        var seekTime = time
        
        c.batch = c.activeVideo.closestBatch(time, minimumDistance: c.batchSnapDistance)
        if let batch = c.batch {
            seekTime = batch.time
        }
        c.ignoreBatch = c.batch
        
        c.doSeek(seekTime)
        
        if final {
            if c.batch != nil {
                c.switchState(.ManualPause)
            } else {
                c.player.play()
            }
        } else {
            c.player.pause()
        }
    }
    
    func annotationEdit(c: PlayerController, event: AnnotationEditEvent) {
        c.switchState(.AnnotationEdit).annotationEdit(c, event: event)
    }
}

class ManualPauseHandler: PlayerHandler {
    
    func start(c: PlayerController) {
        c.player.pause()
    }
    
    func timeUpdate(c: PlayerController, time: Double, lastTime: Double) {
        c.seekBarPosition = time
    }
    
    func userPlay(c: PlayerController) {
        c.switchState(.Playing)
    }
    
    func userSeek(c: PlayerController, time: Double, final: Bool) {
        var seekTime = time
        
        c.batch = c.activeVideo.closestBatch(time, minimumDistance: c.batchSnapDistance)
        if let batch = c.batch {
            seekTime = batch.time
        }
        
        c.doSeek(seekTime)
    }
    
    func annotationEdit(c: PlayerController, event: AnnotationEditEvent) {
        c.switchState(.AnnotationEdit).annotationEdit(c, event: event)
    }
}

class AnnotationPauseHandler: PlayerHandler {
    func start(c: PlayerController) {
        c.player.pause()
    }
    
    func timeUpdate(c: PlayerController, time: Double, lastTime: Double) {
    }
    
    func userPlay(c: PlayerController) {
        c.switchState(.ManualPause)
    }
    
    func userSeek(c: PlayerController, time: Double, final: Bool) {
        c.batch = nil
        c.switchState(.Playing).userSeek(c, time: time, final: final)
    }
    
    func annotationEdit(c: PlayerController, event: AnnotationEditEvent) {
        c.switchState(.AnnotationEdit).annotationEdit(c, event: event)
    }
}

class AnnotationEditHandler: PlayerHandler {
    
    func start(c: PlayerController) {
        c.player.pause()
        c.seekBarPosition = c.time
    }
    
    func timeUpdate(c: PlayerController, time: Double, lastTime: Double) {
    }
    
    func userPlay(c: PlayerController) {
        c.switchState(.Playing)
    }
    
    func userSeek(c: PlayerController, time: Double, final: Bool) {
        c.switchState(.ManualPause).userSeek(c, time: time, final: final)
    }
    
    func annotationEdit(c: PlayerController, event: AnnotationEditEvent) {
        guard let activeVideo = c.activeVideo else { return }
        
        if event.state == .Begin {
            let preUndoPoint = c.createUndoPoint()
            
            if c.batch == nil {
                c.batch = activeVideo.findOrCreateBatch(c.time)
            }
            guard let batch = c.batch else { return }
            
            let result = activeVideo.findOrCreateAnnotationAt(event.position, inBatch: batch)
            
            c.selectAnnotation(result.annotation, undoPoint: preUndoPoint)
            
            if result.wasCreated {
                c.selectedAnnotationMutated()
            }
            
            c.dragging = result.wasCreated
            c.annotationDeadZoneBroken = false
            c.dragOffset = result.annotation.position - event.position
            c.dragStartPos = result.annotation.position

        } else {
            if let annotation = c.selectedAnnotation {
                
                // Do unselect on non-moving tap
                if event.state == .End && !c.dragging && annotation === c.previousSelectedAnnotation {
                    c.selectedAnnotation = nil
                }
                
                let newPos = (event.position + c.dragOffset).clampBetween(Vector2(xy: 0.0), and: Vector2(xy: 1.0))
                
                let delta = (newPos - c.dragStartPos) * c.activeVideo.resolution
                if delta.lengthSquared > pow(c.annotationDeadZone, 2) {
                    if !c.annotationDeadZoneBroken {
                        // TODO: Hide UI
                    }
                    c.dragging = true
                    c.annotationDeadZoneBroken = true
                    c.selectedAnnotationMutated()
                }
                
                if c.dragging {
                    // Don't set the position on end event, since in iOS it tends to jitter a little bit and throw
                    // the annotations slightly off
                    if event.state != .End {
                        annotation.position = newPos
                    }
                }
            }
        }
    }
}

struct UndoPoint {
    let time: Double
    let state: ActiveVideoState
    let batchIndex: Int?
    
    init(time: Double, state: ActiveVideoState, batchIndex: Int?) {
        self.time = time
        self.state = state
        self.batchIndex = batchIndex
    }
}

class PlayerController {
    
    var state: PlayerState = .Playing
    let handlers: [PlayerState: PlayerHandler]
    let player: VideoPlayer
    var activeVideo: ActiveVideo!
    
    var batch: AnnotationBatch?
    var ignoreBatch: AnnotationBatch?
    
    var previousSelectedAnnotation: Annotation?
    var selectedAnnotation: Annotation?
    var annotationDeadZoneBroken: Bool = false
    var dragging: Bool = false
    var dragOffset: Vector2 = Vector2()
    var dragStartPos: Vector2 = Vector2()
    var annotationDeadZone: Float = 0.02
    
    var selectedUndoPoint: UndoPoint?
    
    var time: Double = 0.0
    var seekBarPosition: Double = 0.0
    var isSeeking: Bool = false
    var previousTime: Double = 0.0
    var batchSnapDistance: Double = 0.05
    
    var videoHasEnded: Bool = false
    
    var undoStream: [UndoPoint] = []
    var redoStream: [UndoPoint] = []
    var maxUndoDepth: Int = 256
    
    var wasModified: Bool = false
    
    init(player: VideoPlayer) {
        self.player = player
        self.handlers = [
            PlayerState.Playing: PlayingHandler(),
            PlayerState.ManualPause: ManualPauseHandler(),
            PlayerState.AnnotationPause: AnnotationPauseHandler(),
            PlayerState.AnnotationEdit: AnnotationEditHandler(),
        ]
    }
    
    func resetVideo(video: ActiveVideo) {
        self.activeVideo = video
        
        if let batch = self.batch {
            self.batch = video.closestBatch(batch.time, minimumDistance: 0.1)
            if self.batch == nil {
                self.switchState(.Playing)
            }
        }
    }
    
    func doSeek(time: Double) {
        self.isSeeking = true
        self.player.seekTo(time)
        self.time = time
        self.seekBarPosition = time
    }
    
    func timeUpdate(time: Double) {
        if !self.isSeeking {
            self.time = time
            self.currentHandler.timeUpdate(self, time: time, lastTime: self.previousTime)
        }
        self.previousTime = time
        self.isSeeking = false
    }
    
    func videoEnded() {
        self.switchState(.ManualPause)
        self.videoHasEnded = true
    }
    
    func switchState(state: PlayerState) -> PlayerHandler {
        self.state = state
        let handler = self.handlers[self.state]!
        
        handler.start(self)
        return handler
    }
    
    var currentHandler: PlayerHandler {
        get {
            return self.handlers[self.state]!
        }
    }
    
    func userPlay() {
        if self.videoHasEnded {
            self.doSeek(0.0)
            self.videoHasEnded = false
        }
        
        self.currentHandler.userPlay(self)
    }
    
    func userSeek(relative: Double, final: Bool) {
        guard let duration = player.videoDuration else { return }
        
        self.videoHasEnded = false
        
        let time = relative * duration
        self.currentHandler.userSeek(self, time: time, final: final)
    }
    
    func annotationEdit(event: AnnotationEditEvent) {
        self.currentHandler.annotationEdit(self, event: event)
    }
    
    func annotationDeleteButton() {
        guard let annotation = self.selectedAnnotation else { return }
        
        self.commitUndoPoint(self.createUndoPoint())
        
        self.activeVideo.deleteAnnotation(annotation)
        self.selectedAnnotation = nil
        
        if !self.activeVideo.batches.contains({ $0 === self.batch }) {
            self.batch = nil
        }
    }
    
    func unselectAnnotation() {
        self.selectedAnnotation = nil
    }
    
    func annotationWaitDone() {
        if self.state == .AnnotationPause {
            self.switchState(.Playing)
        }
    }
    
    func selectAnnotation(annotation: Annotation, undoPoint: UndoPoint? = nil) {
        self.selectedUndoPoint = undoPoint ?? self.createUndoPoint()
        self.previousSelectedAnnotation = self.selectedAnnotation
        self.selectedAnnotation = annotation
    }
    
    func selectedAnnotationMutated() {
        if let undoPoint = self.selectedUndoPoint {
            self.commitUndoPoint(undoPoint)
            self.selectedUndoPoint = nil
        }
    }
    
    // Undo / redo
    
    func createUndoPoint() -> UndoPoint {
        let state = self.activeVideo.saveState()
        let batchIndex = self.activeVideo.batches.indexOf({ $0 === self.batch })
        
        self.wasModified = true
        
        return UndoPoint(time: self.time, state: state, batchIndex: batchIndex)
    }
    
    func createUndoPoint(atTime time: Double) -> UndoPoint {
        let state = self.activeVideo.saveState()
        
        let batch = self.activeVideo.closestBatch(time, minimumDistance: 0.05)
        let batchIndex = self.activeVideo.batches.indexOf({ $0 === batch })
        
        return UndoPoint(time: time, state: state, batchIndex: batchIndex)
    }
    
    func commitUndoPoint(undoPoint: UndoPoint) {
        self.redoStream.removeAll(keepCapacity: true)
        
        self.undoStream.append(undoPoint)
        if self.undoStream.count > self.maxUndoDepth {
            self.undoStream.removeFirst()
        }
    }
    
    func restoreStateFrom(inout stream: [UndoPoint], inout andSaveCurrentTo storeStream: [UndoPoint]) -> Bool {
        guard let undoPoint = stream.popLast() else { return false }
        
        storeStream.append(self.createUndoPoint(atTime: undoPoint.time))
        
        self.time = undoPoint.time
        self.activeVideo.restoreState(undoPoint.state)
        self.batch = undoPoint.batchIndex.map({ self.activeVideo.batches[$0] })
        
        return true
    }
    
    func commitUndo() -> Bool {
        return self.restoreStateFrom(&self.undoStream, andSaveCurrentTo: &self.redoStream)
    }
    func commitRedo() -> Bool {
        return self.restoreStateFrom(&self.redoStream, andSaveCurrentTo: &self.undoStream)
    }
    
    var canUndo: Bool {
        return !self.undoStream.isEmpty
    }
    var canRedo: Bool {
        return !self.redoStream.isEmpty
    }
    
    func doUndo() {
        if self.commitUndo() {
            self.postUndoRedo()
        }
    }
    func doRedo() {
        if self.commitRedo() {
            self.postUndoRedo()
        }
    }
    
    func postUndoRedo() {
        self.player.seekTo(self.time)
        self.seekBarPosition = self.time
        self.selectedAnnotation = nil
        self.switchState(.AnnotationEdit)
    }
}
