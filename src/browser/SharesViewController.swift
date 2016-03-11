/*

`SharesViewController` wraps an `WKWebView` and displays the achrails web UI for some group management related functions.

Authentication is done with OAuth2 by passing Bearer token manually to the requests with a custom `X-Refresh-Token` header in case the token expires.

It has some Javascript bridging to modify the look of the site a little bit.

*/

import UIKit
import WebKit

class SharesViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    var webView: WKWebView!

    var endpointUrl: NSURL? {
        return videoRepository.achRails.map { self.getLocalizedUrl($0.endpoint) }
    }

    func getLocalizedUrl(baseUrl: NSURL) -> NSURL {
        let language = NSLocale.preferredLanguages()[safe: 0] ?? "en";
        if ["en", "de", "et", "fi"].contains(language) {
            return baseUrl.URLByAppendingPathComponent(language, isDirectory: true)
        } else {
            return baseUrl
        }
    }
    
    var url: NSURL?
    
    // If the web view tries to load an URL beginning with `trapUrlPrefix` `trapCallback` will be called.
    let trapUrlPrefixBase: String = "achso://authenticate/"
    var trapUrlPrefix: String?
    var trapCallback: (NSURLRequest -> Void)?
    
    override func viewDidLoad() {
        
        let source = "iosLoaded();"
        let userScript = WKUserScript(source: source, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
        
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        userContentController.addScriptMessageHandler(self, name: "setTitle")
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        self.webView.navigationDelegate = self
    
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
        self.trapUrlPrefix = nil
    }
    
    func prepareForManageGroups() throws {
        guard let endpointUrl = self.endpointUrl else {
            throw UserError.notSignedIn
        }
        
        self.url = endpointUrl.URLByAppendingPathComponent("groups")
        self.trapUrlPrefix = nil
    }
    
    func prepareForManageGroup(id: String) throws {
        guard let endpointUrl = self.endpointUrl else {
            throw UserError.notSignedIn
        }
        
        self.url = endpointUrl.URLByAppendingPathComponent("groups/\(id)")
        self.trapUrlPrefix = nil
    }
    
    func prepareForLogin(baseUrl baseUrl: NSURL, callback: (NSURLRequest -> Void)) throws {

        let localizedUrl = getLocalizedUrl(baseUrl)
        let endpointUrl = localizedUrl.URLByAppendingPathComponent("new_session")
        
        guard let components = NSURLComponents(URL: endpointUrl, resolvingAgainstBaseURL: false) else {
            throw UserError.invalidLayersBoxUrl.withDebugError("Could not extract URL components")
        }
        
        let trapUrl = self.trapUrlPrefixBase + NSUUID().lowerUUIDString
        components.queryItems = (components.queryItems ?? []) + [NSURLQueryItem(name: "redirect_to", value: trapUrl)]
        
        self.url = components.URL
        self.trapUrlPrefix = trapUrl
        self.trapCallback = callback
    }
    
    override func viewWillAppear(animated: Bool) {
        if let url = self.url {
            
            let request = NSMutableURLRequest(URL: url)
            if let user = Session.user {
                request.addValue("Bearer \(user.session)", forHTTPHeaderField: "Authorization")
            }
            
            self.webView.loadRequest(request)
        }
    }
    
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        
        if let trapUrlPrefix = self.trapUrlPrefix {
            if navigationAction.request.URLString.hasPrefix(trapUrlPrefix) {
                self.trapCallback?(navigationAction.request)
                self.dismissViewControllerAnimated(true, completion: nil)
                decisionHandler(.Cancel)
                return
            }
        }
        
        decisionHandler(.Allow)
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
