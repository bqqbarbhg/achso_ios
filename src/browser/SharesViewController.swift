import UIKit

class SharesViewController: UIViewController {
    @IBOutlet weak var webView: UIWebView!

    var endpointUrl: NSURL? {
        let baseUrl = videoRepository.achRails.map { $0.endpoint }
        let language = NSLocale.preferredLanguages()[safe: 0] ?? "en";
        if ["en", "de", "et", "fi"].contains(language) {
            return baseUrl?.URLByAppendingPathComponent(language, isDirectory: true)
        } else {
            return baseUrl
        }
    }

    var url: NSURL?
    
    func prepareForShareVideos(ids: [NSUUID]) {
        guard let endpointUrl = self.endpointUrl else { return }
        
        let idStr = ids.map { $0.lowerUUIDString }.joinWithSeparator(",")
        self.url = endpointUrl.URLByAppendingPathComponent("videos/\(idStr)/shares")
    }
    
    func prepareForCreateGroup() {
        guard let endpointUrl = self.endpointUrl else { return }
        
        self.url = endpointUrl.URLByAppendingPathComponent("groups/new")
    }
    
    override func viewWillAppear(animated: Bool) {
        if let url = self.url {
            
            let request = NSMutableURLRequest(URL: url)
            if let user = AuthUser.user {
                request.addValue("Bearer \(user.tokens.access)", forHTTPHeaderField: "Authorization")
                if let refresh = user.tokens.refresh {
                    request.addValue(refresh, forHTTPHeaderField: "X-Refresh-Token")
                }
            }
            
            self.webView.loadRequest(request)
        }
    }
    
    @IBAction func doneButtonPressed(sender: UIBarButtonItem) {
        videoRepository.refreshOnline()
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
