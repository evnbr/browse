//
//  ViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/11/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit
import OnePasswordExtension

class SiteViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate {
    
    var webView: WKWebView!
    
    var statusBar: ColorStatusBarView!
    
    var toolbar: UIToolbar!
    var toolbarInner: UIView!
    
    var searchView: SearchView!
    var scrim: UIButton!
    
    var colorAtTop: UIColor = UIColor.clear
    var colorAtBottom: UIColor = UIColor.clear
    
    var lastTopTransitionTime : CFTimeInterval = 0.0
    var lastBottomTransitionTime : CFTimeInterval = 0.0
    
    var isPanning : Bool = false
    
    var colorDiffs : Sampler = Sampler(period: 12)
    
    var progressView: UIProgressView!
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!
    var tabButton: UIBarButtonItem!
    var urlButton: UIBarButtonItem!
    
    var colorFetcher: WebViewColorFetcher!
    
    var bookmarksController : BookmarksViewController!

    var interactionController: UIPercentDrivenInteractiveTransition?

    
    // http://stackoverflow.com/questions/19764293/inputaccessoryview-docked-at-bottom/23880574#23880574
    override var canBecomeFirstResponder : Bool {
        return true
    }
    
    override var inputAccessoryView:UIView{
        get { return searchView }
    }

    override func loadView() {
        super.loadView()
        
        // --
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 20),
            size:CGSize(
                width: UIScreen.main.bounds.size.width,
                height: UIScreen.main.bounds.size.height - 20
            )
        )

        webView = WKWebView(frame: rect, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self  // req'd for target=_blank override

        view.addSubview(webView)
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigateToText("fonts.google.com")
        webView.allowsBackForwardNavigationGestures = true
        
        toolbar = setUpToolbar()
        statusBar = ColorStatusBarView()
        searchView = SearchView()
        searchView.senderVC = self
        
        scrim = UIButton(frame: UIScreen.main.bounds)
        scrim.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        scrim.addTarget(self, action: #selector(hideSearch), for: .primaryActionTriggered)
        scrim.alpha = 0
        
        bookmarksController = BookmarksViewController()
//        searchController = SearchViewController()
        
        view.addSubview(statusBar)
        view.addSubview(scrim)


        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)


        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInset = .zero
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal

        
        // Detect panning to prevent status bar firing on js-implemented scrolling, like maps and pagers
        let touchRecognizer = UIPanGestureRecognizer()
        touchRecognizer.delegate = self
        touchRecognizer.addTarget(self, action: #selector(self.onWebviewPan))
        webView.scrollView.addGestureRecognizer(touchRecognizer)

        colorFetcher = WebViewColorFetcher(webView)
        
        let colorUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.6,
            target: self,
            selector: #selector(self.updateInterfaceColor),
            userInfo: nil,
            repeats: true
        )
        colorUpdateTimer.tolerance = 0.1
//        RunLoop.main.add(colorUpdateTimer, forMode: RunLoopMode.commonModes)
        
        
    }
    
    
    
    func onWebviewPan(gestureRecognizer:UIGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.began {
            self.isPanning = true
        }
        else if gestureRecognizer.state == UIGestureRecognizerState.ended {
            self.isPanning = false
        }
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func setUpToolbar() -> UIToolbar {
        
        let toolbar = (navigationController?.toolbar)!
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 21),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)
        
        toolbar.addSubview(progressView)
        
        backButton = UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: webView, action: #selector(webView.goBack))
        forwardButton = UIBarButtonItem(image: UIImage(named: "fwd"), style: .plain, target: webView, action: #selector(webView.goForward))
        let actionButton = UIBarButtonItem(image: UIImage(named: "action"), style: .plain, target: self, action: #selector(displayShareSheet))
        tabButton = UIBarButtonItem(image: UIImage(named: "tab"), style: .plain, target: self, action: #selector(displayBookmarks))
        
        backButton.width = 40.0
        forwardButton.width = 40.0
        actionButton.width = 40.0
        tabButton.width = 40.0
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        let negSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        
        space.width = 12.0
        negSpace.width = -12.0
        
        
//        let pwd = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(displayPassword))
        //        urlButton = UIBarButtonItem(title: "URL...", style: .plain, target: self, action: #selector(askURL))
        
        urlButton = UIBarButtonItem(title: "Where to?", style: .plain, target: self, action: #selector(displaySearch))
        
        
        toolbarItems = [negSpace, backButton, forwardButton, flex, urlButton, flex, tabButton, negSpace]
        navigationController?.isToolbarHidden = false
        toolbar.isTranslucent = false
        toolbar.barTintColor = .clear
        toolbar.tintColor = .white
        //        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        
        toolbarInner = UIView()
        toolbarInner.frame = toolbar.bounds
        toolbarInner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        toolbarInner.backgroundColor = .white
        toolbar.addSubview(toolbarInner)
        toolbar.sendSubview(toBack: toolbarInner)
        toolbar.clipsToBounds = true
        
        return toolbar
    }
    
    func handleLongPress(gestureReconizer: UILongPressGestureRecognizer) {
        print("ong pres")
        if gestureReconizer.state == UIGestureRecognizerState.ended {
            displayShareSheet()
        }
    }

    
    
    func updateInterfaceColor() {
        
        if self.isPanning {
            return
        }

        let newColorAtTop    = colorFetcher.getColorAtTop()
        let newColorAtBottom = colorFetcher.getColorAtBottom()


        self.statusBar.back.layer.removeAllAnimations()
        self.toolbar.layer.removeAllAnimations()
        
        if !self.colorAtTop.isEqual(newColorAtTop) {
            self.statusBar.inner.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 20)
            self.statusBar.inner.backgroundColor = newColorAtTop
        }
        if !self.colorAtBottom.isEqual(newColorAtBottom) {
            self.toolbarInner.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -48)
            self.toolbarInner.backgroundColor = newColorAtBottom
        }
        
        let topChange = self.colorAtTop.difference(from: newColorAtTop)
        let bottomChange = self.colorAtBottom.difference(from: newColorAtBottom)

        
        colorDiffs.addSample(value:    topChange > 0.3 ? 1 : 0)
        colorDiffs.addSample(value: bottomChange > 0.3 ? 1 : 0)
        
        let isFrantic : Bool = colorDiffs.sum > 7
        if isFrantic {

            self.statusBar.back.backgroundColor = UIColor.black
            self.toolbar.barTintColor = UIColor.black
            self.toolbar.layoutIfNeeded()
            
            UIApplication.shared.statusBarStyle = .lightContent
            self.toolbar.tintColor = UIColor.white
        }
        else {
            let throttleTop = CACurrentMediaTime() - self.lastTopTransitionTime < 1.0
            let throttleBottom = CACurrentMediaTime() - self.lastBottomTransitionTime < 1.0

            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut, animations: {
                if !self.colorAtTop.isEqual(newColorAtTop) {
                    if !throttleTop && topChange > 0.4 {
                        self.statusBar.inner.transform = CGAffineTransform.identity
                        self.lastTopTransitionTime = CACurrentMediaTime()
                    } else {
                        self.statusBar.back.backgroundColor = newColorAtTop
                    }
                    UIApplication.shared.statusBarStyle = newColorAtTop.isLight()
                        ? .lightContent
                        : .default
                }
                if !self.colorAtBottom.isEqual(newColorAtBottom) {
                    self.toolbar.tintColor = newColorAtBottom.isLight()
                        ? UIColor.white
                        : UIColor.darkText
                    if !throttleBottom && bottomChange > 0.4 {
                        self.toolbarInner.transform = CGAffineTransform.identity
                        self.toolbar.layoutIfNeeded()
                        self.lastBottomTransitionTime = CACurrentMediaTime()
                    } else {
                        self.toolbar.barTintColor = newColorAtBottom
                        self.toolbar.layoutIfNeeded()
                    }
                }
            }) { (completed) in
                if (completed) {
                    self.statusBar.back.backgroundColor = newColorAtTop
                    self.toolbar.barTintColor = newColorAtBottom
                    self.toolbar.layoutIfNeeded()
                }
                else {
                    print("Animation interrupted!")
                }
            }
    
            
            self.webView.backgroundColor = newColorAtTop
            self.webView.scrollView.backgroundColor = newColorAtTop
            self.view.backgroundColor = newColorAtTop
            
            self.progressView.progressTintColor = newColorAtBottom.isLight()
                ? UIColor.white.withAlphaComponent(0.2)
                : UIColor.black.withAlphaComponent(0.08)
        }
        
        self.colorAtTop = newColorAtTop
        self.colorAtBottom = newColorAtBottom

    }
    
    override func viewDidAppear(_ animated: Bool) {
        webView.scrollView.contentInset = .zero
        self.resignFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func displayBookmarks() {
        
        let navigationController = UINavigationController(rootViewController: bookmarksController)
        bookmarksController.sender = self

        present(navigationController, animated: true)
    }
    
    func hideSearch() {
        searchView.textView.resignFirstResponder()
        self.resignFirstResponder()

        let url = self.urlButton.value(forKey: "view") as! UIView
        let back = self.backButton.value(forKey: "view") as! UIView
        let tab = self.tabButton.value(forKey: "view") as! UIView

        UIView.animate(withDuration: 0.3, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            self.scrim.alpha = 0

            url.transform  = CGAffineTransform.identity
            back.transform = CGAffineTransform.identity
            tab.transform  = CGAffineTransform.identity
        })
    }
    
    func displaySearch() {
        let url = self.urlButton.value(forKey: "view") as! UIView
        let back = self.backButton.value(forKey: "view") as! UIView
        let tab = self.tabButton.value(forKey: "view") as! UIView

        UIView.animate(withDuration: 0.3, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            self.scrim.alpha = 1
            
            url.transform  = CGAffineTransform.identity.translatedBy(x: -20, y: -100)
            back.transform = CGAffineTransform.identity.translatedBy(x: -50, y: 0)
            tab.transform  = CGAffineTransform.identity.translatedBy(x: 50, y: 0)
            
        })
        
        searchView.updateAppearance()
        self.becomeFirstResponder()
        searchView.textView.becomeFirstResponder()
        searchView.textView.selectAll(nil) // if not nil, will show actions
    }

    
    func openPage(action: UIAlertAction) {
        let url = URL(string: "https://" + action.title!)!
        webView.load(URLRequest(url: url))
    }
    

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        urlButton.title = getDisplayTitle()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        urlButton.title = getDisplayTitle()
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        if (error as NSError).code == NSURLErrorCancelled {
            print("Cancelled")
            return
        }
        let alert = UIAlertController(title: "Failed Nav", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled {
            print("Cancelled")
            return
        }
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        let alert = UIAlertController(title: "Failed Provisional Nav", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func navigateToText(_ text: String) {
        // TODO: More robust url detection

        if ( text.range(of:".") != nil && text.range(of:" ") == nil ) {
            if (text.hasPrefix("http://") || text.hasPrefix("https://")) {
                let url = URL(string: text)!
                if let btn = urlButton { btn.title = getSiteTitle(url) }
                self.webView.load(URLRequest(url: url))
            }
            else {
                let url = URL(string: "http://" + text)!
                if let btn = urlButton { btn.title = getSiteTitle(url) }
                self.webView.load(URLRequest(url: url))
            }
        }
        else {
            let query = text.addingPercentEncoding(
                withAllowedCharacters: .urlHostAllowed)!
//            let searchURL = "https://duckduckgo.com/?q="
            let searchURL = "https://www.google.com/search?q="
            let url = URL(string: searchURL + query)!
            
            if let btn = urlButton {
                btn.title = getSearchTitle(text)
            }

            self.webView.load(URLRequest(url: url))
        }

    }
    
    func getDisplayTitle() -> String {

        let url = webView.url!
        let absolute : String = url.absoluteString
        let searchURL = "https://www.google.com/search?"
        
        if absolute.hasPrefix(searchURL) {
            guard let components = URLComponents(string: absolute) else { return "?" }
            let queryParam : String = (components.queryItems?.first(where: { $0.name == "q" })?.value)!
            let search : String = queryParam.replacingOccurrences(of: "+", with: " ")
            return getSearchTitle(search)
        }
        
        return getSiteTitle(url)
    }
    
    func getSearchTitle(_ query: String) -> String {
        return "🔍 \(query)"
    }
    
    func getSiteTitle(_ url: URL) -> String {
        let host : String = url.host!
        if host.hasPrefix("www.") {
            let index = host.index(host.startIndex, offsetBy: 4)
            return host.substring(from: index)
        }
        else {
            return host
        }
    }

    
    func displayShareSheet() {
        let avc = UIActivityViewController(activityItems: [webView.url!], applicationActivities: nil)
        self.present(avc, animated: true, completion: nil)
    }

    func displayPassword() {
        OnePasswordExtension.shared().fillItem(intoWebView: self.webView, for: self, sender: nil, showOnlyLogins: true) { (success, error) -> Void in
            if success == false {
                print("Failed to fill into webview: <\(String(describing: error))>")
            }
        }
    }

    
    // this handles target=_blank links by opening them in the same view
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.alpha = 1.0
            
            let isIncreasing = progressView.progress < Float(webView.estimatedProgress)
            progressView.setProgress(Float(webView.estimatedProgress), animated: isIncreasing)
            
            if (webView.estimatedProgress >= 1.0) {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: UIViewAnimationOptions.curveEaseOut, animations: { 
                    self.progressView.progress = 1.0
                    self.progressView.alpha = 0
                }, completion: { (finished) in
                    self.progressView.setProgress(0.0, animated: false)
                })
            }
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : UIColor.clear
            
        }
        else if keyPath == "isLoading" {
            print("loading change")
            //            backButton.isEnabled = webView.canGoBack
            //            forwardButton.isEnabled = webView.canGoForward
        }
        else if keyPath == "title" {
//             catches custom navigation
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : UIColor.clear

            
            if (webView.title != "" && webView.title != title) {
                title = webView.title
                print("Title change: \(title!)")
            }
        }
        else if keyPath == "url" {
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : UIColor.clear

            // catches custom navigation
            // TODO this is probably expensive
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                self.updateInterfaceColor()
//            }
        }
    }



}

