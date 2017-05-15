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

extension UIColor
{
    func isLight() -> Bool
    {
        let components : Array<CGFloat> = self.cgColor.components!
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return (r * 299 + g * 587 + b * 114 ) < 700
    }
    
    static func average(_ colors : Array<UIColor>) -> UIColor {
        let components : Array<Array<CGFloat>> = colors.map { $0.cgColor.components! }
        
        let count = CGFloat(colors.count)
        let r = ( components.reduce(0) { $0 + $1[0] } ) / count
        let g = ( components.reduce(0) { $0 + $1[1] } ) / count
        let b = ( components.reduce(0) { $0 + $1[2] } ) / count
        let a = ( components.reduce(0) { $0 + $1[3] } ) / count
        
        let avgColor = CGColor(colorSpace: colors[0].cgColor.colorSpace!, components: [r,g,b,a])!
        
        return UIColor(cgColor: avgColor)
    }
}


class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {
    
    var webView: WKWebView!
    var statusBack: UIView!
    
    var progressView: UIProgressView!
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!
    var urlButton: UIBarButtonItem!
    
    var colorFetcher: WebViewColorFetcher!

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
        
        goToText("fonts.google.com")
        
        webView.allowsBackForwardNavigationGestures = true
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 21),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)

        self.navigationController?.toolbar.addSubview(progressView)


        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        backButton = UIBarButtonItem(barButtonSystemItem: .rewind, target: webView, action: #selector(webView.goBack))
        forwardButton = UIBarButtonItem(barButtonSystemItem: .fastForward, target: webView, action: #selector(webView.goForward))
        
        let bookmarks = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(displayBookmarks))
        let share = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(displayShareSheet))
        let pwd = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(displayPassword))
        urlButton = UIBarButtonItem(title: "URL...", style: .plain, target: self, action: #selector(askURL))
        

        
        toolbarItems = [backButton, forwardButton, flex, urlButton, flex, pwd, share, bookmarks]
        navigationController?.isToolbarHidden = false
        navigationController?.toolbar.isTranslucent = false
        navigationController?.toolbar.barTintColor = .clear
        navigationController?.toolbar.tintColor = .white
//        navigationController?.toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)

        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:20)
        )
        statusBack = UIView.init(frame: rect)
        statusBack.autoresizingMask = [.flexibleWidth]
        statusBack.backgroundColor = UIColor.black
        self.view?.addSubview(statusBack)
        


        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInset = .zero
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        
//        statusBack.backgroundColor = UIColor.clear
//        webView.scrollView.layer.masksToBounds = false
//        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
//        let blurEffectView = UIVisualEffectView(effect: blurEffect)
//        blurEffectView.frame = statusBack.bounds
//        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        statusBack.addSubview(blurEffectView)


        colorFetcher = WebViewColorFetcher(webView)
        
        let colorUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.4,
            target: self,
            selector: #selector(self.updateStatusBarColor),
            userInfo: nil,
            repeats: true
        )
        colorUpdateTimer.tolerance = 0.2
        // RunLoop.main.add(colorUpdateTimer, forMode: RunLoopMode.commonModes)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        webView.scrollView.contentInset = .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func displayBookmarks() {
        let ac = UIAlertController(title: "Open page…", message: nil, preferredStyle: .actionSheet)
        
        let bookmarks : Array<String> = [
            "apple.com",
            "fonts.google.com",
            "flights.google.com",
            "maps.google.com",
            "plus.google.com",
            "wikipedia.org",
            "theoutline.com",
        ]
        
        bookmarks.forEach() { item in ac.addAction(UIAlertAction(title: item, style: .default, handler: openPage)) }
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(ac, animated: true)
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
        updateStatusBarColor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateStatusBarColor()
        }
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
    
    func goToText(_ text: String) {
        // TODO: More robust url detection
        if text.range(of:".") != nil{
            if (text.hasPrefix("http://") || text.hasPrefix("https://")) {
                let url = URL(string: text)!
                self.webView.load(URLRequest(url: url))
            }
            else {
                let url = URL(string: "http://" + text)!
                self.webView.load(URLRequest(url: url))
            }
        }
        else {
            let query = text.addingPercentEncoding(
                withAllowedCharacters: .urlHostAllowed)!
//            let duck = "https://duckduckgo.com/?q="
            let goog = "https://www.google.com/search?q="
            let url = URL(string: goog + query)!
            self.webView.load(URLRequest(url: url))
        }

    }
    
    func getDisplayTitle() -> String {

        let url = webView.url!
        let absolute : String = url.absoluteString
        let google = "https://www.google.com/search?"
        
        if absolute.hasPrefix(google) {
            guard let components = URLComponents(string: absolute) else { return "?" }
            let queryParam : String = (components.queryItems?.first(where: { $0.name == "q" })?.value)!
            let search : String = queryParam.replacingOccurrences(of: "+", with: " ")
            return "🔍 \(search)"
        }
        
        let host : String = url.host!
        if host.hasPrefix("www.") {
            let index = host.index(host.startIndex, offsetBy: 4)
            return host.substring(from: index)
        }
        else {
            return host
        }
    }

    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.selectAll(nil)
    }

    
    func askURL() {
        let alertController = UIAlertController(title: "Where to?", message: "Current: \(title!)", preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Go", style: .default) { (_) in
            if let field = alertController.textFields?[0] {
                self.goToText(field.text!)
            } else {
                // user did not fill field
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        
        alertController.addTextField { (textField) in
            textField.text = self.webView.url?.absoluteString
            textField.placeholder = "www.example.com"
            textField.keyboardType = UIKeyboardType.URL
            textField.returnKeyType = .go
            textField.delegate = self
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }

    func displayShareSheet() {
        let avc = UIActivityViewController(activityItems: [webView.url!], applicationActivities: nil)
        self.present(avc, animated: true, completion: nil)
    }

    
    func getCSSColor(done: @escaping (_ color: UIColor) -> Void) {
        let js = "(function() { var bodyColor = getComputedStyle(document.body).backgroundColor; if (bodyColor !== \"rgba(0, 0, 0, 0)\") return bodyColor; else return getComputedStyle(document.documentElement).backgroundColor; })()"
        
        webView.evaluateJavaScript(js) { (result, error) in
            if error != nil {
                // print("JS Error: \(error!)")
            }
            else {
                // print("Computed BG: \(result!)")
                let bodyColor : UIColor = self.makeColor(fromCSS: result as! String)!
                done(bodyColor)
            }
        }
    }
    
    func updateStatusBarColor() {
        
//        if webView.scrollView.isDragging {
//            return
//        }
        
        let colorAtTopLeft = colorFetcher.getColorAt(x: 5, y: 1)
        let colorAtTopMid = colorFetcher.getColorAt(x: webView.bounds.size.width / 2, y: 1)
        let colorAtTopRight = colorFetcher.getColorAt(x: webView.bounds.size.width - 5, y: 1)

        let colorAtTop = UIColor.average([colorAtTopLeft, colorAtTopMid, colorAtTopRight])
        
        let colorAtBottomLeft = colorFetcher.getColorAt(
            x: 5,
            y: webView.bounds.size.height - 2)
        let colorAtBottomRight = colorFetcher.getColorAt(
            x: webView.bounds.size.width - 5,
            y: webView.bounds.size.height - 2)

        let colorAtBottom = UIColor.average([colorAtBottomLeft, colorAtBottomRight])
        
        statusBack.layer.removeAllAnimations()
        navigationController?.toolbar.layer.removeAllAnimations()

        UIView.animate(withDuration: 0.2) {
            self.statusBack.backgroundColor = colorAtTop
            self.navigationController?.toolbar.barTintColor = colorAtBottom
            self.navigationController?.toolbar.layoutIfNeeded()
        }
        webView.backgroundColor = colorAtTop
        webView.scrollView.backgroundColor = colorAtTop
        
        UIApplication.shared.statusBarStyle = colorAtTop.isLight()
            ? .lightContent
            : .default
        
        navigationController?.toolbar.tintColor = colorAtBottom.isLight()
            ? UIColor.white
            : UIColor.darkText
        progressView.progressTintColor = colorAtBottom.isLight()
            ? UIColor.white.withAlphaComponent(0.2)
            : UIColor.black.withAlphaComponent(0.08)

    }
    
    
    func makeColor(fromCSS str: String) -> UIColor! {
        if str.hasPrefix("rgba(") || str.hasPrefix("rgb(") {
            let parts = str.components(separatedBy: NSCharacterSet.decimalDigits.inverted)
            let values : Array<Float> = parts.filter {
                if let _ = Float($0) { return true }
                else { return false }
            }.map { Float($0)! }
            return UIColor(
                colorLiteralRed: values[0] / 255.0,
                green: values[1] / 255.0,
                blue: values[2] / 255.0,
                alpha: 1
            )
        }
        return nil
    }
    
    func displayPassword() {
        OnePasswordExtension.shared().fillItem(intoWebView: self.webView, for: self, sender: nil, showOnlyLogins: false) { (success, error) -> Void in
            if success == false {
                print("Failed to fill into webview: <\(error)>")
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
            
            // TODO this is probably expensive
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                self.updateStatusBarColor()
//            }
        }
        else if keyPath == "isLoading" {
            print("loading change")
            //            backButton.isEnabled = webView.canGoBack
            //            forwardButton.isEnabled = webView.canGoForward
        }
        else if keyPath == "title" {
//             catches custom navigation
            if (webView.title != "" && webView.title != title) {
                title = webView.title
                print("Title change: \(title!)")
//                updateStatusBarColor()
            }
        }
        else if keyPath == "url" {
            // catches custom navigation
            // TODO this is probably expensive
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                self.updateStatusBarColor()
//            }
        }
    }



}

