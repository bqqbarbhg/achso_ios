import UIKit

class PlayerViewController: UIViewController, VideoPlayerDelegate {
    
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var playButton: PlayButtonView!
    @IBOutlet weak var seekBar: SeekBarView!
    
    @IBOutlet weak var annotationToolbar: UIView!
    @IBOutlet weak var annotationTextField: UITextField!
    
    let videoPlayer = VideoPlayer()
    let playerController: PlayerController
    var activeVideo: ActiveVideo?
    
    var toolbarBottomConstraint: NSLayoutConstraint!
    
    var activeSelectedAnnotation: Annotation?
    
    required init?(coder aDecoder: NSCoder) {
        self.playerController = PlayerController(player: self.videoPlayer)
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.playerController = PlayerController(player: self.videoPlayer)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        // TODO: Smarter status bar style
        // For now expect the status bar to lay on the black background
        return .LightContent;
    }
    
    func keyboardWillChangeFrame(notification: NSNotification) {
        let info = notification.userInfo!
        let duration = info[UIKeyboardAnimationDurationUserInfoKey]!.doubleValue
        let keyboardFrame = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        
        UIView.animateWithDuration(duration, animations: {
            self.toolbarBottomConstraint.constant = -keyboardFrame.size.height
        })
        
        self.view.layoutIfNeeded()
    }
    
    func keyboardWillHide(notification: NSNotification) {
        let info = notification.userInfo!
        let duration = info[UIKeyboardAnimationDurationUserInfoKey]!.doubleValue

        UIView.animateWithDuration(duration, animations: {
            self.toolbarBottomConstraint.constant = 0
        })
        
        self.view.layoutIfNeeded()
    }
    
    override func viewDidLoad() {
        self.toolbarBottomConstraint = NSLayoutConstraint(
            item: self.annotationToolbar,
            attribute: NSLayoutAttribute.Bottom,
            relatedBy: NSLayoutRelation.Equal,
            toItem: self.bottomLayoutGuide,
            attribute: NSLayoutAttribute.Top,
            multiplier: 1.0,
            constant: 0.0)
        
        self.view.addConstraint(self.toolbarBottomConstraint)
        
        // Hidden by default
        self.annotationToolbar.hidden = true
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillChangeFrame:", name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
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
        
        self.videoView.callback = { event in
            self.playerController.annotationEdit(event)
            self.refreshView()
        }
        
        self.refreshView()
    }

    func refreshView() {
        self.playButton.buttonMode = {
            switch self.playerController.state {
            case .Playing: return .Pause
            case .ManualPause: return .Play
            case .AnnotationPause: return .Pause
            case .AnnotationEdit: return .Play
            }
        }()
        
        // TODO: Propertyify
        if let batch = self.playerController.batch {
            self.videoView.showAnnotations(batch.annotations, selected: self.playerController.selectedAnnotation)
        } else {
            self.videoView.showAnnotations([], selected: nil)
        }
        
        if let selectedAnnotation = self.playerController.selectedAnnotation {
            self.annotationToolbar.hidden = false
            
            if self.activeSelectedAnnotation !== selectedAnnotation {
                self.activeSelectedAnnotation = selectedAnnotation
                self.annotationTextField.text = selectedAnnotation.text
            }
        } else {
            self.annotationToolbar.hidden = true
            self.activeSelectedAnnotation = nil
        }
        
        if let activeVideo = self.activeVideo {
            self.seekBar.annotationTimes = activeVideo.batches.map { batch in
                batch.time / activeVideo.duration
            }
        }
        
        if let duration = videoPlayer.videoDuration {
            self.seekBar.seekBarPositionPercentage = self.playerController.seekBarPosition / duration
        }
    }
    
    @IBAction func annotationTextFieldEditingChanged(sender: UITextField) {
        updateAnnotationText()
    }
    
    @IBAction func annotationTextFieldEditingDidEnd(sender: UITextField) {
        updateAnnotationText()
    }
    
    func updateAnnotationText() {
        guard let text = annotationTextField.text else { return }
        
        if let selectedAnnotation = self.activeSelectedAnnotation {
            selectedAnnotation.text = text
        }
    }
    
    func createVideo(sourceVideoUrl: NSURL) {
        self.videoPlayer.loadVideo(sourceVideoUrl)
        
        let video = Video()
        let activeVideo = ActiveVideo(video: video)
        
        if let duration = self.videoPlayer.videoDuration {
            activeVideo.duration = duration
        }
        if let videoSize = self.videoPlayer.videoSize {
            let size = Vector2.init(cgSize: videoSize)
            let relative = size / min(size.x, size.y)
            activeVideo.resolution = relative
        }
        
        self.activeVideo = activeVideo
        self.playerController.activeVideo = activeVideo
    }
    
    func timeUpdate(time: Double) {
        self.playerController.timeUpdate(time)
        self.refreshView()
    }
}