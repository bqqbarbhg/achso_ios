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
        }
        
        c.seekBarPosition = time
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
        
        // TODO: Timer
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
    }
    
    func timeUpdate(c: PlayerController, time: Double, lastTime: Double) {
        c.seekBarPosition = time
    }
    
    func userPlay(c: PlayerController) {
        c.switchState(.Playing)
    }
    
    func userSeek(c: PlayerController, time: Double, final: Bool) {
        c.switchState(.ManualPause).userSeek(c, time: time, final: final)
    }
    
    func annotationEdit(c: PlayerController, event: AnnotationEditEvent) {
        guard let activeVideo = c.activeVideo else { return }
        
        if c.batch == nil {
            c.batch = activeVideo.findOrCreateBatch(c.time)
        }
        
        guard let batch = c.batch else { return }
        
        if event.state == .Begin {
            activeVideo.findOrCreateAnnotationAt(event.position, inBatch: batch)
        }
    }
}

class PlayerController {
    
    var state: PlayerState = .Playing
    let handlers: [PlayerState: PlayerHandler]
    let player: VideoPlayer
    var activeVideo: ActiveVideo!
    
    var batch: ActiveVideo.AnnotationBatch?
    var ignoreBatch: ActiveVideo.AnnotationBatch?
    
    var time: Double = 0.0
    var seekBarPosition: Double = 0.0
    var isSeeking: Bool = false
    var previousTime: Double = 0.0
    var batchSnapDistance: Double = 0.05
    
    init(player: VideoPlayer) {
        self.player = player
        self.handlers = [
            PlayerState.Playing: PlayingHandler(),
            PlayerState.ManualPause: ManualPauseHandler(),
            PlayerState.AnnotationPause: AnnotationPauseHandler(),
            PlayerState.AnnotationEdit: AnnotationEditHandler(),
        ]
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
        self.currentHandler.userPlay(self)
    }
    
    func userSeek(relative: Double, final: Bool) {
        guard let duration = player.videoDuration else { return }
        
        let time = relative * duration
        self.currentHandler.userSeek(self, time: time, final: final)
    }
    
    func annotationEdit(event: AnnotationEditEvent) {
        self.currentHandler.annotationEdit(self, event: event)
    }
}
