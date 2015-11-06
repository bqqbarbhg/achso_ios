import UIKit

class PlayerViewController: UIViewController, VideoViewDelegate {
    
    @IBOutlet weak var videoView: VideoView!
    
    let videoPlayer = VideoPlayer()
    let playerController: PlayerController
    
    required init?(coder aDecoder: NSCoder) {
        self.playerController = PlayerController(player: self.videoPlayer)
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.playerController = PlayerController(player: self.videoPlayer)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func viewDidAppear(animated: Bool) {
        self.videoView.attachPlayer(self.videoPlayer)
        self.videoPlayer.play()
        
        // HACK TODO: Real annotations
        let annotation = Annotation()
        annotation.position = Vector2(x: 0.7, y: 0.3)
        let annotations = [annotation]
        
        self.videoView.showAnnotations(annotations)
        self.videoView.delegate = self
    }
    
    func createVideo(sourceVideoUrl: NSURL) {
        self.videoPlayer.loadVideo(sourceVideoUrl)
    }
    
    func videoViewEvent(event: PlayerUserEvent) {
        switch event {
        case .SeekPreview(let time):
            playerController.userSeek(time, final: false)
        case .SeekTo(let time):
            playerController.userSeek(time, final: true)
        case .SeekCancel:
            // HACKish: If the user cancels a seek then do a virtual seek to the curren time ending the seek mode
            playerController.userSeek(videoPlayer.avPlayer.currentTime().seconds, final: true)
        case .PlayPause:
            playerController.userPlay()
            
            // HAAAAAACk
            videoView.seekBarView.updatePlaying(playerController.state != .Playing)
        }
    }
}