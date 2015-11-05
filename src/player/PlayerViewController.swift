import UIKit

class PlayerViewController: UIViewController {
    
    @IBOutlet weak var videoView: VideoView!
    
    let videoPlayer = VideoPlayer()
    
    override func viewDidAppear(animated: Bool) {
        self.videoView.attachPlayer(self.videoPlayer)
        self.videoPlayer.play()
        
        // HACK TODO: Real annotations
        let annotation = Annotation()
        annotation.position = Vector2(x: 0.7, y: 0.3)
        let annotations = [annotation]
        
        self.videoView.showAnnotations(annotations)
    }
    
    func createVideo(sourceVideoUrl: NSURL) {
        self.videoPlayer.loadVideo(sourceVideoUrl)
    }
}