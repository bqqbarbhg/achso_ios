import UIKit

class LoginWebViewController: UIViewController, UIWebViewDelegate {
    
    @IBOutlet weak var webView: UIWebView!
    
    var loginUrl: NSURL?
    var trapUrlPrefix: String?
    var trapCallback: (NSURLRequest -> Void)?
    
    override func viewDidLoad() {
        self.webView.delegate = self
    }
    
    func prepareForLogin(url url: NSURL, trapUrlPrefix: String, callback: (NSURLRequest -> Void)) {
        self.loginUrl = url
        self.trapUrlPrefix = trapUrlPrefix
        self.trapCallback = callback
    }
    
    override func viewWillAppear(animated: Bool) {
        guard let loginUrl = self.loginUrl else {
            // TODO: Error message
            self.dismissViewControllerAnimated(true, completion: nil)
            return
        }
        
        let request = NSURLRequest(URL: loginUrl)
        self.webView.loadRequest(request)
    }
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let trapUrlPrefix = self.trapUrlPrefix else { return true }

        if request.URLString.hasPrefix(trapUrlPrefix) {
            self.trapCallback?(request)
            self.dismissViewControllerAnimated(true, completion: nil)
            return false
        } else {
            return true
        }
    }
}
