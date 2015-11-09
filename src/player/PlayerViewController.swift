import UIKit

class PlayerViewController: UIViewController, VideoPlayerDelegate {
    
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var playButton: PlayButtonView!
    @IBOutlet weak var seekBar: SeekBarView!
    
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
    
    override func viewWillAppear(animated: Bool) {
        // Show as pause button during segue
        self.playButton.setModeNoAniamtion(.Pause)
    }
    
    override func viewDidAppear(animated: Bool) {
        self.videoView.attachPlayer(self.videoPlayer)
        self.videoPlayer.play()
        
        self.videoPlayer.delegate = self
        
        // No animation when setting the button mode later
        self.playButton.buttonMode = .Initial
        self.playButton.callback = {
            self.playerController.userPlay()
            self.refreshView()
        }

        self.seekBar.callback = { event in
            switch event {
            case .Preview(let time):
                self.playerController.userSeek(time, final: false)
            case .SeekTo(let time):
                self.playerController.userSeek(time, final: true)
            case .Cancel:
                // Do a virtual final seek to current position when cancelled
                if let duration = self.videoPlayer.videoDuration {
                    let time = self.videoPlayer.avPlayer.currentTime().seconds
                    self.playerController.userSeek(time / duration, final: true)
                }
            }
        }
        
        self.refreshView()
    }

    func refreshView() {
        self.playButton.buttonMode = {
            switch self.playerController.state {
            case .Playing: return .Pause
            case .ManualPause: return .Play
            }
        }()
    }
    
    func createVideo(sourceVideoUrl: NSURL) {
        self.videoPlayer.loadVideo(sourceVideoUrl)
    }
    
    func timeUpdate(time: Double) {
        // TODO: Do this through player controller
        guard let duration = videoPlayer.videoDuration else { return }
        
        self.seekBar.seekBarPositionPercentage = time / duration
    }
}