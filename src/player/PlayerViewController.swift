/*

`PlayerViewController` is the view controller for the video player activity.

It mostly just loads the video into an `AVPlayerView` (see AVPlayerView.swift) and bridges the UI to the `PlayerController` (see PlayerController.swift).

The UI is mostly updated in a single function `refreshView()` which moves the data from the `PlayerController` to the interface components.

*/

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

    var videoPlayer: VideoPlayer?
    var playerController: PlayerController?
    
    var video: Video?
    var activeVideo: ActiveVideo?
    var keyboardVisible: Bool = false
    
    var toolbarBottomConstraint: NSLayoutConstraint!
    var subtitlesBottomConstraint: NSLayoutConstraint!
    
    var activeSelectedAnnotation: Annotation?
    
    var isWaiting: Bool = false
    var isAnnotationInputVisible: Bool = false
    
    var annotationWaitToken: Int = 0
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
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
        self.title = self.activeVideo?.video.title
        
        self.videoView.alpha = 0.0
        
        if let videoPlayer = self.videoPlayer {
            self.videoView?.attachPlayer(videoPlayer)
            videoPlayer.delegate = self
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        
        // No animation when setting the button mode later
        self.playButton.buttonMode = .Initial
        self.playButton.callback = {
            self.playerController?.userPlay()
            self.refreshView()
        }

        self.seekBar.callback = { event in
            switch event {
            case .Preview(let time):
                self.playerController?.userSeek(time, final: false)
            case .SeekTo(let time):
                self.playerController?.userSeek(time, final: true)
            case .Cancel:
                // Do a virtual final seek to current position when cancelled
                if let videoPlayer = self.videoPlayer,
                    duration = videoPlayer.videoDuration {
                    let time = videoPlayer.avPlayer.currentTime().seconds
                    self.playerController?.userSeek(time / duration, final: true)
                }
            }
        }
        
        self.videoView.callback = { event in
            if self.playerController?.activeVideo != nil && self.playerController?.batch != nil {
                let temp = self.playerController?.activeVideo.findAnnotationAt(event.position, inBatch: (self.playerController?.batch)!)
                let selected = self.playerController?.selectedAnnotation
                
                if temp != nil && selected != nil {
                    if temp?.position.x == selected?.position.x && temp?.position.y == temp?.position.y && temp?.time == selected?.time {
                        self.playerController?.annotationEdit(event)
                        self.refreshView()
                        return
                    }
                }
            }
            if !self.isAnnotationInputVisible && event.state == .Begin {
                self.isAnnotationInputVisible = true
                self.playerController?.annotationEdit(event)
                self.refreshView()
            } else if event.state == .Begin {
                self.annotationToolbar.hidden = true
                self.isAnnotationInputVisible = false
                self.playerController?.selectedAnnotation = nil
            }
        }
        
        self.refreshView()
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.videoPlayer?.pause()
    }
    
    override func viewDidDisappear(animated: Bool) {
        self.videoPlayer = nil
        self.playerController = nil
        self.activeVideo = nil
        self.activeSelectedAnnotation = nil
        self.keyboardVisible = false
        self.isAnnotationInputVisible = false
        self.videoView.removePlayer()
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
        guard let playerController = self.playerController,
            videoPlayer = self.videoPlayer else { return }
        
        self.playButton.buttonMode = {
            switch playerController.state {
            case .Playing: return .Pause
            case .ManualPause: return .Play
            case .AnnotationPause: return .Pause
            case .AnnotationEdit: return .Play
            }
        }()
        
        // TODO: Propertyify
        if let batch = playerController.batch {
            self.videoView.showAnnotations(batch.annotations, selected: playerController.selectedAnnotation)
        } else {
            self.videoView.showAnnotations([], selected: nil)
        }
        
        if let selectedAnnotation = playerController.selectedAnnotation {
            self.annotationToolbar.hidden = false
            
            if self.activeSelectedAnnotation !== selectedAnnotation {
                self.activeSelectedAnnotation = selectedAnnotation
                self.annotationTextField.text = selectedAnnotation.text
            }
        } else {
            self.annotationToolbar.hidden = true
            self.isAnnotationInputVisible = false
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
            self.seekBar.seekBarPositionPercentage = playerController.seekBarPosition / duration
        }
        
        if let batch = playerController.batch {
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
        
        if playerController.state == .AnnotationPause {
            if !self.isWaiting {
                
                let waitTime: Double = {
                    if let batch = playerController.batch {
                        return self.calculateAnnotationWaitTime(batch.annotations)
                    } else {
                        return self.calculateAnnotationWaitTime([])
                    }
                }()
                
                self.annotationWaitToken += 1
                
                self.performSelector("annotationWaitDone:", withObject: self.annotationWaitToken, afterDelay: waitTime)
 
                self.annotationWaitBar.animateProgress(waitTime)
                
                self.isWaiting = true
            }
        }
        
        if self.isWaiting && playerController.state != .AnnotationPause {
            
            self.annotationWaitBar.stopAnimation()
            
            self.isWaiting = false
        }
        
        self.undoButton.enabled = playerController.canUndo
        self.redoButton.enabled = playerController.canRedo
        
        if let activeVideo = self.activeVideo {
            let snapDistanceInPoints = 10.0
            let barLengthInPoints = Double(seekBar.seekBarWidth)
            
            let videoDurationInSeconds = activeVideo.duration
            let snapDurationInSeconds = (snapDistanceInPoints / barLengthInPoints) * videoDurationInSeconds
            
            playerController.batchSnapDistance = snapDurationInSeconds
        }
    }
    
    func updateAnnotationText() {
        guard let text = annotationTextField.text else { return }
        
        if let selectedAnnotation = self.activeSelectedAnnotation {
            selectedAnnotation.text = text
        }
        
        self.playerController?.selectedAnnotationMutated()
        refreshView()
    }
    
    func annotationWaitDone(object: AnyObject) {
        if object as? Int != self.annotationWaitToken { return }
        
        self.playerController?.annotationWaitDone()
        self.annotationWaitBar.stopAnimation()
        self.isWaiting = false
    }
    
    func timeUpdate(time: Double) {
        self.playerController?.timeUpdate(time)
        self.refreshView()
    }
    
    func videoEnded() {
        self.playerController?.videoEnded()
        self.refreshView()
    }
    
    @IBAction func annotationTextFieldEditingChanged(sender: UITextField) {
        updateAnnotationText()
    }
    
    @IBAction func annotationTextFieldEditingDidEnd(sender: UITextField) {
        updateAnnotationText()
    }
    
    @IBAction func annotationDeleteButton(sender: UIButton) {
        playerController?.annotationDeleteButton()
        refreshView()
    }
    
    @IBAction func annotationSaveButton(sender: UIButton) {
        playerController?.unselectAnnotation()
        refreshView()
    }
    
    @IBAction func undoButtonPressed(sender: UIBarButtonItem) {
        playerController?.doUndo()
        self.refreshView()
    }
    @IBAction func redoButtonPressed(sender: UIBarButtonItem) {
        playerController?.doRedo()
        self.refreshView()
    }
    
    @IBAction func saveButtonPressed(sender: UIBarButtonItem) {
        guard let activeVideo = self.activeVideo else { return }
        
        do {
            if self.playerController?.wasModified ?? false {
                let video = activeVideo.toVideo()
                video.hasLocalModifications = true
                try videoRepository.saveVideo(video)
                videoRepository.refreshOnline()
            }
        } catch {
            // TODO
        }
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func setVideo(video: Video) throws {
        
        let videoPlayer = VideoPlayer(url: try video.videoUri.realUrl.unwrap())
        
        self.videoPlayer = videoPlayer
        self.video = video
    }
    
    func videoLoaded() {
        self.view.setNeedsLayout()
        self.videoView.setNeedsLayout()
        self.videoView.doLayoutSubviews(animated: false)
        self.refreshView()
        
        
        UIView.transitionWithView(self.videoView, duration: 0.2, options: UIViewAnimationOptions.CurveEaseOut, animations: {
            self.videoView.alpha = 1.0
        }, completion: { _ in
            self.videoPlayer?.play()
        })
        
        guard let videoPlayer = self.videoPlayer, video = self.video else { return  }
        
        if self.playerController?.state == .Some(.Playing) {
            videoPlayer.play()
        }
        
        let playerController = PlayerController(player: videoPlayer)
        
        let activeVideo = ActiveVideo(video: video, user: videoRepository.user)
        
        if let duration = videoPlayer.videoDuration {
            activeVideo.duration = duration
        }
        if let videoSize = videoPlayer.videoSize {
            let size = Vector2.init(cgSize: videoSize)
            let relative = size / min(size.x, size.y)
            activeVideo.resolution = relative
        }
        
        self.activeVideo = activeVideo
        playerController.activeVideo = activeVideo
        
        
        self.playerController = playerController
    }
    
    func videoFailedToLoad() {
        self.showErrorModal(self.videoPlayer?.playerItem?.error ?? DebugError("Player item error not found"),
            title: NSLocalizedString("error_on_video_play", comment: "Error title when the video fails to play")) {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    func videoDidUpdate(video: Video?) {
        
        if let video = video {
            do {
                try AppDelegate.instance.saveVideo(video)
            } catch {
            }
            
            guard let videoPlayer = self.videoPlayer,
                playerController = self.playerController else {
                    self.video = video
                    return
            }
            
            if playerController.wasModified { return }
            
            let activeVideo = ActiveVideo(video: video, user: videoRepository.user)
            
            if let duration = videoPlayer.videoDuration {
                activeVideo.duration = duration
            }
            if let videoSize = videoPlayer.videoSize {
                let size = Vector2.init(cgSize: videoSize)
                let relative = size / min(size.x, size.y)
                activeVideo.resolution = relative
            }
            
            self.activeVideo = activeVideo
            playerController.activeVideo = activeVideo
        }
    }
}
