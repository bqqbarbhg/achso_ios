/*

`SharesViewController` wraps an `WKWebView` and displays the achrails web UI for some group management related functions.

Authentication is done with OAuth2 by passing Bearer token manually to the requests with a custom `X-Refresh-Token` header in case the token expires.

It has some Javascript bridging to modify the look of the site a little bit.

*/

import UIKit
import WebKit

class SharesViewController: UIViewController, WKScriptMessageHandler {
    
    var webView: WKWebView!

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
    
    override func viewDidLoad() {
        
        let source = "iosLoaded();"
        let userScript = WKUserScript(source: source, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
        
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        userContentController.addScriptMessageHandler(self, name: "setTitle")
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        self.view.addSubview(self.webView)
    }
    
    override func viewWillLayoutSubviews() {
        self.webView.frame = self.view.bounds
    }
    
    func prepareForShareVideos(ids: [NSUUID]) throws {
        guard let endpointUrl = self.endpointUrl else {
            throw UserError.notSignedIn
        }
        
        let idStr = ids.map { $0.lowerUUIDString }.joinWithSeparator(",")
        self.url = endpointUrl.URLByAppendingPathComponent("videos/\(idStr)/shares")
    }
    
    func prepareForCreateGroup() throws {
        guard let endpointUrl = self.endpointUrl else {
            throw UserError.notSignedIn
        }
        
        self.url = endpointUrl.URLByAppendingPathComponent("groups/new")
    }
    
    func prepareForManageGroups() throws {
        guard let endpointUrl = self.endpointUrl else {
            throw UserError.notSignedIn
        }
        
        self.url = endpointUrl.URLByAppendingPathComponent("groups")
    }
    
    func prepareForManageGroup(id: String) throws {
        guard let endpointUrl = self.endpointUrl else {
            throw UserError.notSignedIn
        }
        
        self.url = endpointUrl.URLByAppendingPathComponent("groups/\(id)")
    }
    
    override func viewWillAppear(animated: Bool) {
        if let url = self.url {
            
            let request = NSMutableURLRequest(URL: url)
            if let user = Session.user {
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
    
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        switch message.name {
        case "setTitle":
            self.navigationItem.title = message.body as? String
        default:
            break
        }
    }
}
