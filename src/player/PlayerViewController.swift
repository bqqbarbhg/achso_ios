import UIKit

class PlayerViewController: UIViewController, VideoPlayerDelegate {
    
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var playControlsView: UIView!
    @IBOutlet weak var playButton: PlayButtonView!
    @IBOutlet weak var seekBar: SeekBarView!
    
    @IBOutlet weak var annotationToolbar: UIView!
    @IBOutlet weak var annotationTextField: UITextField!

    @IBOutlet weak var subtitlesLabel: UILabel!
    @IBOutlet weak var annotationWaitBar: AnnotationWaitBarView!

    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!

    let videoPlayer = VideoPlayer()
    let playerController: PlayerController
    var activeVideo: ActiveVideo?
    var keyboardVisible: Bool = false
    
    var toolbarBottomConstraint: NSLayoutConstraint!
    var subtitlesBottomConstraint: NSLayoutConstraint!
    
    var activeSelectedAnnotation: Annotation?
    
    var isWaiting: Bool = false
    
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
    
    func keyboardWillShow(notification: NSNotification) {
        self.keyboardVisible = true
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

        self.keyboardVisible = false
        
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
        
        self.subtitlesBottomConstraint = NSLayoutConstraint(
            item: self.subtitlesLabel,
            attribute: NSLayoutAttribute.Bottom,
            relatedBy: NSLayoutRelation.Equal,
            toItem: self.bottomLayoutGuide,
            attribute: NSLayoutAttribute.Top,
            multiplier: 1.0,
            constant: 0.0)
        self.view.addConstraint(self.subtitlesBottomConstraint)
        
        self.subtitlesLabel.layer.shadowColor = hexCgColor(0x000000, alpha: 1.0)
        self.subtitlesLabel.layer.shadowOffset = CGSize.zero
        self.subtitlesLabel.layer.shadowRadius = 2.0
        self.subtitlesLabel.layer.shadowOpacity = 0.5
        self.subtitlesLabel.layer.masksToBounds = false
        self.subtitlesLabel.layer.shouldRasterize = true
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
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
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let fontSize: CGFloat = {
            if self.view.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.Compact {
                return 20.0
            } else {
                return 26.0
            }
        }()
        
        self.subtitlesLabel.font = self.subtitlesLabel.font.fontWithSize(fontSize)
    }
    
    func calculateAnnotationWaitTime(annotations: [Annotation]) -> Double {
        
        // Time constants in seconds.
        let timeAlways = 2.0
        let timePerAnnotation = 0.5
        let timePerSubtitle = 1.0
        let timePerLetter = 0.02
        let timeMaximum = 10.0
        
        var waitTime = timeAlways
        
        for annotation in annotations {
            waitTime += timePerAnnotation
            
            let text = annotation.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            
            let length = text.characters.count
            if length > 0 {
                waitTime += timePerSubtitle
                waitTime += Double(length) * timePerLetter
            }
        }
        
        return min(waitTime, timeMaximum)
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
            
            if self.keyboardVisible {
                self.view.endEditing(true)
            }
        }
        
        if let activeVideo = self.activeVideo {
            self.seekBar.annotationTimes = activeVideo.batches.map { batch in
                batch.time / activeVideo.duration
            }
        }
        
        if let duration = videoPlayer.videoDuration {
            self.seekBar.seekBarPositionPercentage = self.playerController.seekBarPosition / duration
        }
        
        if let batch = self.playerController.batch {
            var texts = [String]()
            
            for annotation in batch.annotations {
                let text = annotation.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                if !text.isEmpty {
                    texts.append(text)
                }
            }
            
            subtitlesLabel.text = texts.joinWithSeparator("\n")
            subtitlesLabel.hidden = false
        } else {
            subtitlesLabel.text = nil
            subtitlesLabel.hidden = true
        }
        
        // TODO: Move subtitles if play controls are hidden
        self.subtitlesBottomConstraint.constant = self.playControlsView.frame.minY - self.view.frame.maxY
        
        if self.playerController.state == .AnnotationPause {
            if !self.isWaiting {
                
                let waitTime: Double = {
                    if let batch = self.playerController.batch {
                        return self.calculateAnnotationWaitTime(batch.annotations)
                    } else {
                        return self.calculateAnnotationWaitTime([])
                    }
                }()
                
                self.performSelector("annotationWaitDone:", withObject: nil, afterDelay: waitTime)
                self.annotationWaitBar.animateProgress(waitTime)
                
                self.isWaiting = true
            }
        }
        
        if self.isWaiting && self.playerController.state != .AnnotationPause {
            
            self.annotationWaitBar.stopAnimation()
            
            self.isWaiting = false
        }
        
        self.undoButton.enabled = self.playerController.canUndo
        self.redoButton.enabled = self.playerController.canRedo
        
        if let activeVideo = self.activeVideo {
            let snapDistanceInPoints = 10.0
            let barLengthInPoints = Double(seekBar.seekBarWidth)
            
            let videoDurationInSeconds = activeVideo.duration
            let snapDurationInSeconds = (snapDistanceInPoints / barLengthInPoints) * videoDurationInSeconds
            
            self.playerController.batchSnapDistance = snapDurationInSeconds
        }
    }
    
    func updateAnnotationText() {
        guard let text = annotationTextField.text else { return }
        
        if let selectedAnnotation = self.activeSelectedAnnotation {
            selectedAnnotation.text = text
        }
        
        self.playerController.selectedAnnotationMutated()
        refreshView()
    }
    
    func annotationWaitDone(object: AnyObject) {
        self.playerController.annotationWaitDone()
        self.annotationWaitBar.stopAnimation()
        self.isWaiting = false
    }
    
    @IBAction func annotationTextFieldEditingChanged(sender: UITextField) {
        updateAnnotationText()
    }
    
    @IBAction func annotationTextFieldEditingDidEnd(sender: UITextField) {
        updateAnnotationText()
    }
    
    @IBAction func annotationDeleteButton(sender: UIButton) {
        playerController.annotationDeleteButton()
        refreshView()
    }
    
    @IBAction func annotationSaveButton(sender: UIButton) {
        playerController.unselectAnnotation()
        refreshView()
    }
    
    @IBAction func undoButtonPressed(sender: UIBarButtonItem) {
        playerController.doUndo()
        self.refreshView()
    }
    @IBAction func redoButtonPressed(sender: UIBarButtonItem) {
        playerController.doRedo()
        self.refreshView()
    }
    
    @IBAction func saveButtonPressed(sender: UIBarButtonItem) {
        guard let activeVideo = self.activeVideo else { return }
        let video = activeVideo.toVideo()
        
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        do {
            try appDelegate.saveVideo(video)
        } catch {
            // TODO
        }
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func setVideo(video: Video) {
        let user = User()
        user.name = "test"
        
        self.videoPlayer.loadVideo(video.videoUri)
        let activeVideo = ActiveVideo(video: video, user: user)
        
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