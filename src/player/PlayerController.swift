import Foundation

enum PlayerState {
    case Playing
    case ManualPause
}

protocol PlayerHandler {
    func start(c: PlayerController)
    func userPlay(c: PlayerController)
    func userSeek(c: PlayerController, time: Double, final: Bool)
}

class PlayingHandler: PlayerHandler {
    
    func start(c: PlayerController) {
        c.player.play()
    }
    
    func userPlay(c: PlayerController) {
        c.switchState(.ManualPause)
    }
    
    func userSeek(c: PlayerController, time: Double, final: Bool) {
        c.player.seekTo(time)
        
        if final {
            c.player.play()
        } else {
            c.player.pause()
        }
    }
}

class ManualPauseHandler: PlayerHandler {
    
    func start(c: PlayerController) {
        c.player.pause()
    }
    
    func userPlay(c: PlayerController) {
        c.switchState(.Playing)
    }
    
    func userSeek(c: PlayerController, time: Double, final: Bool) {
        c.player.seekTo(time)
    }
}

class PlayerController {
    
    var state: PlayerState = .Playing
    let handlers: [PlayerState: PlayerHandler]
    let player: VideoPlayer
    
    init(player: VideoPlayer) {
        self.player = player
        self.handlers = [
            PlayerState.Playing: PlayingHandler(),
            PlayerState.ManualPause: ManualPauseHandler(),
        ]
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
    
}
