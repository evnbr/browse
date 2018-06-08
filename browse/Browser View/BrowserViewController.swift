//
//  BrowserViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/11/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit
import OnePasswordExtension
import pop

class BrowserViewController: UIViewController, UIGestureRecognizerDelegate, UIActivityItemSource {
    
    var tabSwitcher: TabSwitcherViewController
    
    let webViewManager = WebViewManager()
    
    var webView: WKWebView!
    var snapshotView: UIImageView = UIImageView()
    var currentTab: Tab
    
    var topConstraint : NSLayoutConstraint!
    var accessoryHeightConstraint : NSLayoutConstraint!
    var aspectConstraint : NSLayoutConstraint!
    var statusHeightConstraint : NSLayoutConstraint!

    var colorSampler: WebviewColorSampler!
    
    lazy var searchVC = SearchViewController()
    
    var statusBar: ColorStatusBarView!
    
    var toolbar: BrowserToolbarView!
    var toolbarPlaceholder = UIView()
    var accessoryView: GradientColorChangeView!
    
    var errorView: UIView!
    var cardView: UIView!
    var contentView: UIView!
    var overlay: UIView!
    var grad: GradientView!
    
    var overflowController: UIAlertController!
    var onePasswordExtensionItem : NSExtensionItem!
    var gestureController : BrowserGestureController!

    var navigationToHide : WKNavigation? = nil// = false

    
    // MARK: - Derived properties
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBar.backgroundColor.isLight ? .lightContent : .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return gestureController.isDismissing
    }
    
    var isShowingToolbar : Bool {
        return toolbar.heightConstraint.constant > 0
    }
    
    var displayLocation : String {
        guard let url = webView?.url else { return "" }
        if let q = url.searchQuery { return q }
        else { return displayURL }
    }
    
    var displayURL : String {
        get {
            let url = webView.url!
            return url.displayHost
        }
    }
    
    var isBlank : Bool {
        return webView?.url == nil
    }
    
    var isSearching : Bool {
        get {
            guard let url = webView.url else { return false }
            return (url.absoluteString.contains("google") || url.absoluteString.contains("duck")) && url.absoluteString.contains("?q=")
        }
    }
    
    var editableLocation : String {
        get {
            guard let url = webView?.url else { return "" }
            if let q = url.searchQuery { return q }
            else { return url.absoluteString }
        }
    }
    
    
    func hideUntilNavigationDone(navigation: WKNavigation? ) {
        isSnapshotMode = true
        if let nav = navigation {
            // nav delegate will track and alert when done
            navigationToHide = nav
        }
        else {
            // probably a javascript navigation, nav delegate can't track
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.finishHiddenNavigation()
            }
        }
    }
    @objc func finishHiddenNavigation() {
        self.navigationToHide = nil //false
        self.isSnapshotMode = false
    }

    func setVisit(_ visit: Visit, wkItem: WKBackForwardListItem) {
        let list = webView.backForwardList
        if list.currentItem == wkItem { return }
        
        setSnapshot(visit.snapshot)
        if let color = visit.topColor { statusBar.backgroundColor = color }
        if let color = visit.bottomColor { toolbar.backgroundColor = color }
        statusBar.label.text = visit.title
        toolbar.text = visit.url?.displayHost
        
        let nav = webView.go(to: wkItem)
        hideUntilNavigationDone(navigation: nav)
    }
    func canNavigateTo(wkItem: WKBackForwardListItem) -> Bool {
        let list = webView.backForwardList
        return list.currentItem == wkItem
            || list.backList.contains(wkItem)
            || list.forwardList.contains(wkItem)
    }
    
    // MARK: - Lifecycle
    
    init(tabSwitcher: TabSwitcherViewController, tab: Tab) {
        self.currentTab = tab
        self.tabSwitcher = tabSwitcher
        super.init(nibName: nil, bundle: nil)
        setTab(tab)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setTab(_ newTab: Tab) {
        if view == nil {
            fatalError("Can't set tab before view loaded")
        }
        if newTab == currentTab && webView != nil { return }

        let oldWebView = webView
        
        oldWebView?.removeFromSuperview()
        
        oldWebView?.uiDelegate = nil
        oldWebView?.navigationDelegate = nil
        oldWebView?.scrollView.delegate = nil

        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        
        currentTab = newTab
        webView = webViewManager.webViewFor(newTab)
        
        if let img = newTab.currentVisit?.snapshot {
            snapshotView.image = img
        }
        else {
            snapshotView.image = nil
        }
        
        if let newTop = newTab.currentVisit?.topColor {
            statusBar.backgroundColor = newTop
        }
        else {
            statusBar.backgroundColor = .white
        }
        if let newBottom = newTab.currentVisit?.bottomColor {
            toolbar.backgroundColor = newBottom
        }
        else {
            toolbar.backgroundColor = .white
        }
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.delegate = gestureController
        webView.scrollView.isScrollEnabled = true
                
        contentView.insertSubview(webView, belowSubview: snapshotView)
        topConstraint = webView.topAnchor.constraint(equalTo: statusBar.bottomAnchor)
        topConstraint.isActive = true
        
        webView.leftAnchor.constraint(equalTo: cardView.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: cardView.rightAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Const.toolbarHeight).isActive = true
        toolbarPlaceholder.topAnchor.constraint(equalTo: webView.bottomAnchor).isActive = true
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        
        webView.addInputAccessory(toolbar: accessoryView)
        
        updateLoadingState()
        showToolbar(animated: true)
        
        if let startLocation = currentTab.currentVisit?.url, self.isBlank {
            navigateTo(startLocation)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let isLandscape = size.width > size.height
        statusHeightConstraint.constant = isLandscape ? 0 : Const.statusHeight
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        cardView = UIView(frame: cardViewDefaultFrame)
        cardView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let shadowView = UIView(frame: view.bounds)
        shadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shadowView.layer.shadowRadius = Const.shadowRadius
        shadowView.layer.shadowOpacity = shadowAlpha
//        shadowView.layer.shouldRasterize = true
        let path = UIBezierPath(roundedRect: view.bounds, cornerRadius: Const.thumbRadius)
        shadowView.layer.shadowPath = path.cgPath

        contentView = UIView(frame: cardViewDefaultFrame)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.radius = Const.cardRadius
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .white

        overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black
        overlay.alpha = 0
        
        grad = GradientView(frame: view.bounds.insetBy(dx: -60, dy: -60) )
        grad.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        grad.alpha = 0
        
        view.addSubview(cardView)
        cardView.addSubview(shadowView)
        cardView.addSubview(contentView)
        
        statusBar = ColorStatusBarView()
        toolbar = setUpToolbar()
        
        toolbarPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        toolbarPlaceholder.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapToolbarPlaceholder))
        toolbarPlaceholder.addGestureRecognizer(tap)
        
        contentView.addSubview(toolbarPlaceholder)
        
        snapshotView.contentMode = .scaleAspectFill
        snapshotView.translatesAutoresizingMaskIntoConstraints = false
        snapshotView.frame.size = CGSize(
            width: cardView.bounds.width,
            height: cardView.bounds.height - Const.statusHeight - Const.toolbarHeight
        )
        let tapSnap = UITapGestureRecognizer(target: self, action: #selector(self.finishHiddenNavigation))
        snapshotView.addGestureRecognizer(tapSnap)
        
        contentView.addSubview(snapshotView)
        contentView.addSubview(toolbar)
        contentView.addSubview(statusBar)
        contentView.bringSubview(toFront: statusBar)
        contentView.bringSubview(toFront: toolbar)
        
        contentView.addSubview(overlay)
        constrain4(contentView, overlay)
        contentView.addSubview(grad)

        constrainTop3(statusBar, contentView)
        statusHeightConstraint = statusBar.heightAnchor.constraint(equalToConstant: Const.statusHeight)
        
        snapshotView.isHidden = true
        aspectConstraint = snapshotView.heightAnchor.constraint(equalTo: snapshotView.widthAnchor, multiplier: 1)
        
        NSLayoutConstraint.activate([
            statusHeightConstraint,
            aspectConstraint,
            snapshotView.topAnchor.constraint(equalTo: statusBar.bottomAnchor),
            snapshotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            snapshotView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            toolbar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            toolbar.widthAnchor.constraint(equalTo: cardView.widthAnchor),
            toolbar.bottomAnchor.constraint(equalTo: toolbarPlaceholder.bottomAnchor),
            toolbarPlaceholder.leftAnchor.constraint(equalTo: cardView.leftAnchor),
            toolbarPlaceholder.rightAnchor.constraint(equalTo: cardView.rightAnchor),
            toolbarPlaceholder.heightAnchor.constraint(equalToConstant: Const.toolbarHeight)
        ])
        
        accessoryView = setupAccessoryView()
        
        colorSampler = WebviewColorSampler()
        colorSampler.delegate = self
        
        gestureController = BrowserGestureController(for: self)
        
        let searchSwipe = UIPanGestureRecognizer(target: self, action: #selector(showSearchGesture(_:)))
        toolbar.searchField.addGestureRecognizer(searchSwipe)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }
    
    @objc func showSearchGesture(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            searchVC.displaySearchTransition.showKeyboard = false
            searchVC.setBackground(toolbar.backgroundColor)
            present(searchVC, animated: true) {
                self.searchVC.displaySearchTransition.showKeyboard = true
            }
        }
        searchVC.handleEntrancePan(gesture)
    }
    
    var cardViewDefaultFrame : CGRect {
        return CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height// - Const.toolbarHeight
        )
    }
    
    func hideToolbar(animated : Bool = true) {
        if !webView.scrollView.isScrollableY { return }
        if webView.isLoading { return }
        if toolbar.heightConstraint.constant == 0 { return }
        
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                self.webView.scrollView.scrollIndicatorInsets.bottom = -Const.toolbarHeight
                self.toolbar.contentsAlpha = 0
            }
        )
        toolbar.heightConstraint.springConstant(to: 0)
        webView.scrollView.springBottomInset(to: -Const.toolbarHeight)

    }
    @objc func tapToolbarPlaceholder() {
        showToolbar(adjustScroll: true)
    }
    func showToolbar(animated: Bool = true, adjustScroll: Bool = false) {
        if toolbar.heightConstraint.constant == Const.toolbarHeight { return }
        
        let dist = Const.toolbarHeight - toolbar.heightConstraint.constant

        if (animated) {
            UIView.animate(
                withDuration: animated ? 0.2 : 0,
                delay: 0,
                options: [.curveEaseInOut, .allowAnimatedContent],
                animations: {
                    self.webView.scrollView.scrollIndicatorInsets.bottom = 0
                    self.toolbar.contentsAlpha = 1
            })
            
            toolbar.heightConstraint.springConstant(to: Const.toolbarHeight)
            webView.scrollView.springBottomInset(to: 0)
            if adjustScroll {
                let scroll = webView.scrollView
                var newOffset = scroll.contentOffset
                newOffset.y = min(scroll.maxScrollY, scroll.contentOffset.y + dist)
                scroll.springContentOffset(to: newOffset)
            }
        }
        else {
            toolbar.heightConstraint.constant = Const.toolbarHeight
            webView.scrollView.contentInset.bottom = 0
            webView.scrollView.scrollIndicatorInsets.bottom = 0
            toolbar.contentsAlpha = 1
        }
    }

    func setUpToolbar() -> BrowserToolbarView {
        let toolbar = BrowserToolbarView(frame: CGRect(x: 0, y: 0, width: cardView.frame.width, height: Const.toolbarHeight))
        
        toolbar.searchField.setAction(displaySearch)
        toolbar.backButton.setAction(goBack)
        toolbar.stopButton.setAction(stop)
        toolbar.tabButton.setAction(displayHistory)
        toolbar.tintColor = .darkText
        return toolbar
    }
    
    func displayHistory() {
        let historyVC = HistoryTreeViewController()
        updateSnapshot {
            historyVC.loadViewIfNeeded() // to set up scrollpos
            historyVC.treeMaker.loadTabs(selectedTabID: self.currentTab.objectID) {
                self.present(historyVC, animated: true, completion: nil)
            }
        }
    }
    
    func displaySearch() {
        searchVC.setBackground(toolbar.backgroundColor)
        searchVC.modalPresentationStyle = .custom
        present(searchVC, animated: true, completion: nil)
    }
    
    func stop() {
        webView.stopLoading()
        finishHiddenNavigation()
    }
    
    func goBack() {
        if webView.canGoBack { webView.goBack() }
        else if let parent = currentTab.parentTab {
            gestureController.swapTo(parentTab: parent)
        }
    }
    
    func setupAccessoryView() -> GradientColorChangeView {
        let acc = GradientColorChangeView(frame: CGRect(x: 0, y: 0, width: 375, height: 48))
        acc.tintColor = UIColor.darkText
        acc.backgroundColor = UIColor(r: 0.83, g: 0.84, b: 0.85).withAlphaComponent(0.95)
//        acc.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        let blur = PlainBlurView(frame: acc.frame)
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        acc.addSubview(blur)
        
        let dismissButton = ToolbarTextButton(title: "Done", withIcon: nil) {
            UIResponder.firstResponder()?.resignFirstResponder()
        }
        dismissButton.size = .medium
        dismissButton.sizeToFit()
        acc.addSubview(dismissButton)
        dismissButton.autoresizingMask = .flexibleLeftMargin
        dismissButton.frame.origin.x = acc.frame.width - dismissButton.frame.width
        
        let passButton = ToolbarIconButton(icon: UIImage(named: "key")) {
            self.displayPassword()
        }
        
        accessoryHeightConstraint = acc.heightAnchor.constraint(equalToConstant: 24)
        accessoryHeightConstraint.priority = .required
        accessoryHeightConstraint.isActive = true
        
//        passButton.frame.size.height = acc.frame.height
        passButton.autoresizingMask = .flexibleLeftMargin
        passButton.frame.origin.x = dismissButton.frame.origin.x - passButton.frame.width - 8
        
        acc.addSubview(passButton)
        
        return acc
    }
    
    var isSnapshotMode : Bool {
        get {
            return !snapshotView.isHidden
        }
        set {
            if newValue {
                snapshotView.isHidden = false
                webView.isHidden = true
            } else {
                webView.isHidden = false
                snapshotView.isHidden = true
            }
        }
    }
    
    func updateSnapshot(then done: @escaping () -> Void = { }) {
        guard !webView.isHidden else {
            done()
            return
        }
        // Image snapshot
        currentTab.updateSnapshot(from: webView) { [weak self] img in
            self?.setSnapshot(img)
            done()
        }
    }
    
    func setSnapshot(_ image : UIImage?) {
        guard let image = image else { return }
        snapshotView.image = image
        
        let newAspect = image.size.height / image.size.width
        if newAspect != aspectConstraint.multiplier {
            snapshotView.removeConstraint(aspectConstraint)
            aspectConstraint = snapshotView.heightAnchor.constraint(equalTo: snapshotView.widthAnchor, multiplier: newAspect, constant: 0)
            aspectConstraint.isActive = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        showToolbar(animated: false)
        statusBar.backgroundView.alpha = 1
        toolbar.backgroundView.alpha = 1
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        hideToolbar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        webView.scrollView.contentInset = .zero
        self.setNeedsStatusBarAppearanceUpdate()

        self.colorSampler.startUpdates()
        
//         disable mysterious delays
//         https://stackoverflow.com/questions/19799961/uisystemgategesturerecognizer-and-delayed-taps-near-bottom-of-screen
        let window = view.window!
        let gr0 = window.gestureRecognizers![0] as UIGestureRecognizer
        let gr1 = window.gestureRecognizers![1] as UIGestureRecognizer
        gr0.delaysTouchesBegan = false
        gr1.delaysTouchesBegan = false
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        print("BrowserVC received memory warning")
        // Dispose of any resources that can be recreated.
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        colorSampler.stopUpdates()
    }
    
    func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Gestures
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Actions    
    
    @objc func copyURL() {
        UIPasteboard.general.string = self.editableLocation
    }
    
    
    // MARK: - Share ActivityViewController and 1Password
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return self.webView!.url!
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType?) -> Any? {
        if OnePasswordExtension.shared().isOnePasswordExtensionActivityType(activityType?.rawValue) {
            // Return the 1Password extension item
            return self.onePasswordExtensionItem
        } else {
            // Return the current URL
            return self.webView!.url!
        }
        
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivityType?) -> String {
        // Because of our UTI declaration, this UTI now satisfies both the 1Password Extension and the usual NSURL for Share extensions.
        return "org.appextension.fill-browser-action"
        
    }
    
    func makeShareSheet(completion: @escaping (UIActivityViewController) -> ()) {
        if webView.url == nil { return }
        
        let onePass = OnePasswordExtension.shared()
        
        onePass.createExtensionItem(
            forWebView: self.webView,
            completion: { (extensionItem, error) in
                if (extensionItem == nil) {
                    print("Failed to create an extension item: \(String(describing: error))")
                    return
                }
                self.onePasswordExtensionItem = extensionItem
                
                let activityItems : [Any] = [self, self.webView.url!]
                let avc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                avc.excludedActivityTypes = [ .addToReadingList ]
                avc.completionWithItemsHandler = { (type, completed, returned, error) in
                    guard onePass.isOnePasswordExtensionActivityType(type?.rawValue)
                        && returned != nil
                        && returned!.count > 0 else { return }
                    onePass.fillReturnedItems(returned, intoWebView: self.webView, completion: {(success, error) in
                        if !success {
                            print("Failed to fill into webview: \(String(describing: error))")
                        }
                    })
                }
                completion(avc)
        })
    }
    
    @objc func displayShareSheet() {
        self.resignFirstResponder() // without this, action sheet dismiss animation won't go all the way
        makeShareSheet { avc in
            self.present(avc, animated: true, completion: nil)
        }
    }
    
    
    func displayPassword() {
        OnePasswordExtension.shared().fillItem(
            intoWebView: self.webView,
            for: self,
            sender: nil,
            showOnlyLogins: true,
            completion: { (success, error) in
                if success == false {
                    print("Failed to fill into webview: <\(String(describing: error))>")
                }
            }
        )
    }

    // MARK: - Webview State
    
    func navigateTo(_ url: URL) {
        errorView?.removeFromSuperview()
        toolbar.text = url.displayHost
        toolbar.progress = 0
        
        let nav = webView.load(URLRequest(url: url))
        
        // Does it feel faster if old page instantle disappears?
        hideUntilNavigationDone(navigation: nav)
        snapshotView.image = nil
        toolbar.backgroundColor = .white
        statusBar.backgroundColor = .white
    }
    
    @objc func hideError() {
        errorView.removeFromSuperview()
    }
    
    func makeError() -> UIView {
        let ev = UIView(frame: view.bounds)
        ev.translatesAutoresizingMaskIntoConstraints = false
        ev.backgroundColor = UIColor.red
        
        let errorLabel = UILabel()
        errorLabel.textAlignment = .natural
        errorLabel.font = UIFont.systemFont(ofSize: 16.0)
        errorLabel.numberOfLines = 0
        errorLabel.textColor = .white
        ev.addSubview(errorLabel)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideError))
        ev.addGestureRecognizer(tap)
        
        return ev
    }

    func displayError(text: String) {
        if errorView == nil { errorView = makeError() }
        
        errorView.backgroundColor = toolbar.backgroundColor
        let errorLabel = errorView.subviews.first as! UILabel
        errorLabel.text = text
        errorLabel.textColor = toolbar.tintColor
        let size = errorLabel.sizeThatFits(CGSize(width: cardView.bounds.size.width - 40, height: 200))
        errorLabel.frame = CGRect(origin: CGPoint(x: 20, y: 20), size: size)
        
        cardView.addSubview(errorView)
        
        errorView.leftAnchor.constraint(equalTo: cardView.leftAnchor).isActive = true
        errorView.rightAnchor.constraint(equalTo: cardView.rightAnchor).isActive = true
        errorView.bottomAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
        errorView.heightAnchor.constraint(equalToConstant: 60).isActive = true
    }
    
    
    func resetSizes() {
        view.frame = UIScreen.main.bounds
        webView?.frame.origin.y = Const.statusHeight
        cardView.transform = .identity
        cardView.bounds.size = cardViewDefaultFrame.size
        cardView.center = view.center        
    }
    
    func updateLoadingState() {
        guard isViewLoaded else { return }
        assert(webView != nil, "nil webview")
        
        toolbar.text = self.displayLocation
        statusBar.label.text = webView.title
        
        UIView.animate(withDuration: 0.25) {
            self.toolbar.backButton.isEnabled = self.webView.canGoBack || self.currentTab.hasParent
        }
        
        if self.webView.isLoading {
            showToolbar()
        }
        
        toolbar.isLoading = webView.isLoading
        toolbar.isSecure = webView.hasOnlySecureContent
        toolbar.isSearch = isSearching || isBlank
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = webView.isLoading
        
        HistoryManager.shared.sync(
            tab: currentTab,
            with: webView.backForwardList
        )
    }
        
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            toolbar.progress = CGFloat(webView.estimatedProgress)
        }
        updateLoadingState()
    }
}

private weak var currentFirstResponder: UIResponder?

extension UIResponder {
    
    static func firstResponder() -> UIResponder? {
        currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(self.findFirstResponder), to: nil, from: nil, for: nil)
        return currentFirstResponder
    }
    
    @objc func findFirstResponder(sender: AnyObject) {
        currentFirstResponder = self
    }
    
}


extension BrowserViewController : WebviewColorSamplerDelegate {
    
    var sampledWebView: WKWebView {
        return webView
    }
    
    var shouldUpdateSample: Bool {
        return isViewLoaded
            && view.window != nil
            && !gestureController.isDismissing
            && UIApplication.shared.applicationState == .active
            && webView != nil
            && !isSnapshotMode
            && !webView.scrollView.isOverScrolledTop
            && !webView.scrollView.isOverScrolledBottom
    }
    
    var bottomSamplePosition: CGFloat {
        return cardView.bounds.height - Const.statusHeight - toolbar.heightConstraint.constant
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame: NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let newHeight = keyboardRectangle.height
        
        // Hack to prevent accessory of showing up at bottom
        accessoryHeightConstraint?.constant = newHeight < 50 ? 0 : 48
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        // Hack to prevent accessory of showing up at bottom
        accessoryHeightConstraint?.constant = 0
    }
    
    func didTakeSample() {
        checkFixedNav()
    }

    func checkFixedNav() {
//        webView.evaluateFixedNav() { (isFixed) in
//            let sv = self.webView.scrollView
//
//            let transparentStatusBar = sv.isScrollableY
//                && sv.contentOffset.y > Const.statusHeight
//                && !isFixed.top
//            let transparentToolbar = sv.isScrollableY
//                && !isFixed.bottom
//                && sv.contentOffset.y < sv.maxScrollY - Const.toolbarHeight
//            let newStatusAlpha : CGFloat = transparentStatusBar ? 0.8 : 1
//            let newToolbarAlpha : CGFloat = transparentToolbar ? 0.8 : 1
//
//            if newStatusAlpha != self.statusBar.backgroundView.alpha
//                || newToolbarAlpha != self.toolbar.backgroundView.alpha {
//                UIView.animate(withDuration: 0.6, delay: 0, options: [.beginFromCurrentState], animations: {
//                    self.statusBar.backgroundView.alpha = newStatusAlpha
//                    self.toolbar.backgroundView.alpha = newToolbarAlpha
//                })
//            }
//        }
    }
    
    func topColorChange(_ newColor: UIColor) {
        if newColor != currentTab.currentVisit?.topColor {
            currentTab.currentVisit?.topColor = newColor
            return
        }
        else if shouldUpdateSample {
            statusBar.transitionBackground(to: newColor, from: .bottomToTop)
            UIView.animate(withDuration: 0.6, delay: 0, options: [.beginFromCurrentState], animations: {
                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    func bottomColorChange(_ newColor: UIColor) {
        if newColor != currentTab.currentVisit?.bottomColor {
            currentTab.currentVisit?.bottomColor = newColor
            return
        }
        else if shouldUpdateSample {
            toolbar.transitionBackground(to: newColor, from: .topToBottom)
        }
    }
    
    
    
    func cancelColorChange() {
        statusBar.cancelColorChange()
        toolbar.cancelColorChange()
    }
}

