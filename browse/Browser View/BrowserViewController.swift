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

// swiftlint:disable:next type_body_length
class BrowserViewController: UIViewController, UIGestureRecognizerDelegate {

    let tabManager = TabManager()
    var toolbarManager: ToolbarScrollawayManager!
//    var webviewBottomConstraint: NSLayoutConstraint!
    let webViewManager = WebViewManager()
    
    var webView: WKWebView!
    var currentTab: Tab?
    
    var topConstraint: NSLayoutConstraint!
    var accessoryHeightConstraint: NSLayoutConstraint!
    var statusHeightConstraint: NSLayoutConstraint!
    
    var topOverscrollCoverHeightConstraint: NSLayoutConstraint!
    var bottomOverscrollCoverHeightConstraint: NSLayoutConstraint!

    let colorSampler = WebviewColorSampler()

    lazy var searchVC = SearchViewController()

    let progressView = UIProgressView(progressViewStyle: .bar)
    var statusBar: ColorStatusBarView!
    
    let topOverscrollCover = UIView(frame: .zero)
    let bottomOverscrollCover = UIView(frame: .zero)

    var toolbar: BrowserToolbarView!
    var toolbarPlaceholder = UIView()
    var accessoryView: GradientColorChangeView!
    
    var errorView: UIView!
    var cardView: UIView!
    var contentView: UIView!

    var overflowController: UIAlertController!
    var onePasswordExtensionItem: NSExtensionItem!

    var navigationToHide: WKNavigation?

    // MARK: - Derived properties

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBar.backgroundColor.isLight ? .lightContent : .darkContent
    }

    override var prefersStatusBarHidden: Bool {
        return false //gestureController.isDismissing
    }

    var isShowingToolbar: Bool {
        return toolbar.heightConstraint.constant > 0
    }

    var displayLocation: String {
        guard let url = webView?.url else { return "" }
        if let query = url.searchQuery {
            return query
        }
        return displayURL ?? "No Location"
    }

    var displayURL: String? {
        let url = webView.url!
        return url.displayHost
    }

    var isBlank: Bool {
        return webView?.url == nil
    }

    var isSearching: Bool {
        guard let str = webView.url?.absoluteString else { return false }
        return (str.contains("google") || str.contains("duck")) && str.contains("?q=")
    }

    var editableLocation: String {
        guard let url = webView?.url else { return "" }
        if let query = url.searchQuery {
            return query
        } else {
            return url.absoluteString
        }
    }

    func setVisit(_ visit: Visit, wkItem: WKBackForwardListItem) {
        let list = webView.backForwardList
        if list.currentItem == wkItem { return }

        if let color = visit.topColor {
            topColorChange(color, offset: webView.scrollView.contentOffset)
            statusBar.backgroundColor = color
        }
        if let color = visit.bottomColor {
            bottomColorChange(color, offset: webView.scrollView.contentOffset)
            toolbar.backgroundColor = color
        }
        toolbar.text = visit.url?.displayHost

        let nav = webView.go(to: wkItem)
    }

    func canNavigateTo(wkItem: WKBackForwardListItem) -> Bool {
        let list = webView.backForwardList
        return list.currentItem == wkItem
            || list.backList.contains(wkItem)
            || list.forwardList.contains(wkItem)
    }

    // MARK: - Lifecycle

    var progressObserver: NSKeyValueObservation?
    var titleObserver: NSKeyValueObservation?
    var urlObserver: NSKeyValueObservation?
    var canGoBackObserver: NSKeyValueObservation?

    func setTab(_ newTab: Tab) {
        if view == nil {
            fatalError("Can't set tab before view loaded")
        }
        if newTab == currentTab && webView != nil { return }

        // Cleanup
        if let oldWebView = webView {
            oldWebView.removeFromSuperview()
            clearObservers(for: oldWebView)
        }

        // Setup
        currentTab = newTab
        webView = webViewManager.webViewFor(newTab)

        statusBar.backgroundColor = newTab.currentVisit?.topColor ?? .black
        toolbar.backgroundColor = newTab.currentVisit?.bottomColor ?? .black

        webView.scrollView.delegate = toolbarManager
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = true

        contentView.insertSubview(webView, belowSubview: statusBar)
//        topConstraint = webView.topAnchor.constraint(equalTo: statusBar.bottomAnchor, constant: 0)
        topConstraint = webView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 0)
        topConstraint.isActive = true

        webView.leftAnchor.constraint(equalTo: cardView.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: cardView.rightAnchor).isActive = true
//        webView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Const.toolbarHeight).isActive = true
//        webviewBottomConstraint = cardView.bottomAnchor.constraint(equalTo: webView.bottomAnchor, constant: 0)
//        webviewBottomConstraint.isActive = true
//
        webView.heightAnchor.constraint(equalTo: cardView.heightAnchor, constant: 0).isActive = true
        toolbarPlaceholder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true

//        webView.addInputAccessory(toolbar: accessoryView)

        observeLoadingChanges(for: webView)
        updateLoadingState()

        toolbarManager.showToolbar(animated: true)

        if let startLocation = currentTab?.currentVisit?.url, self.isBlank {
            navigateTo(startLocation)
        }
    }

    func clearObservers(for webView: WKWebView) {
        webView.uiDelegate = nil
        webView.navigationDelegate = nil
        webView.scrollView.delegate = nil

        progressObserver = nil
        titleObserver = nil
        urlObserver = nil
        canGoBackObserver = nil
    }

    func observeLoadingChanges(for webView: WKWebView) {
        progressObserver = webView.observe(\.estimatedProgress) { _, _ in
            let progress = CGFloat(webView.estimatedProgress)
            self.updateLoadingState(estimatedProgress: progress)
        }
        titleObserver = webView.observe(\.title) { _, _ in
            self.updateLoadingState()
        }
        urlObserver = webView.observe(\.url) { _, _ in
            self.updateLoadingState()
        }
        canGoBackObserver = webView.observe(\.canGoBack) { _, _ in
            UIView.animate(withDuration: 0.25) {
                self.toolbar.backButton.isEnabled = self.webView.canGoBack || self.currentTab!.hasParent
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let isLandscape = size.width > size.height
        statusHeightConstraint.constant = isLandscape ? 0 : Const.statusHeight
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        toolbarManager = ToolbarScrollawayManager(for: self)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        cardView = UIView(frame: cardViewDefaultFrame)
        cardView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        contentView = UIView(frame: cardViewDefaultFrame)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.radius = Const.cardRadius
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .clear

        view.addSubview(cardView)
        cardView.addSubview(contentView)
        
        topOverscrollCover.backgroundColor = .black
        bottomOverscrollCover.backgroundColor = .black
        topOverscrollCover.translatesAutoresizingMaskIntoConstraints = false
        bottomOverscrollCover.translatesAutoresizingMaskIntoConstraints = false

        statusBar = ColorStatusBarView()
        toolbar = setUpToolbar()

        toolbarPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        toolbarPlaceholder.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapToolbarPlaceholder))
        toolbarPlaceholder.addGestureRecognizer(tap)

        contentView.addSubview(toolbarPlaceholder)
        contentView.addSubview(toolbar)
        contentView.addSubview(statusBar)
        contentView.addSubview(topOverscrollCover)
        contentView.addSubview(bottomOverscrollCover)

        contentView.bringSubview(toFront: statusBar)
        contentView.bringSubview(toFront: toolbar)

        constrainBottom3(bottomOverscrollCover, contentView)
        constrainTop3(topOverscrollCover, contentView)
        constrainTop3(statusBar, contentView)
        
        progressView.trackTintColor = .clear
        progressView.layer.sublayers![1].cornerRadius = 2
        progressView.subviews[1].clipsToBounds = true

        progressView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressView)
        
        statusHeightConstraint = statusBar.heightAnchor.constraint(equalToConstant: Const.statusHeight)
        
        topOverscrollCoverHeightConstraint = topOverscrollCover.heightAnchor.constraint(equalToConstant: Const.statusHeight)
        bottomOverscrollCoverHeightConstraint = bottomOverscrollCover.heightAnchor.constraint(equalToConstant: Const.toolbarHeight)

//        toolbar.heightConstraint.constant = 40
        
        additionalSafeAreaInsets.top = 20
//        additionalSafeAreaInsets.bottom = 60
        
        NSLayoutConstraint.activate([
            statusHeightConstraint,
            topOverscrollCoverHeightConstraint,
            bottomOverscrollCoverHeightConstraint,
            toolbar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            toolbar.widthAnchor.constraint(equalTo: cardView.widthAnchor),
            toolbar.bottomAnchor.constraint(equalTo: toolbarPlaceholder.bottomAnchor),
            toolbarPlaceholder.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            toolbarPlaceholder.leftAnchor.constraint(equalTo: cardView.leftAnchor),
            toolbarPlaceholder.rightAnchor.constraint(equalTo: cardView.rightAnchor),
            toolbarPlaceholder.heightAnchor.constraint(equalToConstant: Const.toolbarHeight),
            progressView.topAnchor.constraint(equalTo: statusBar.bottomAnchor, constant: -2),
            progressView.centerXAnchor.constraint(equalTo: statusBar.centerXAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 120),
//            progressView.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 16),
//            progressView.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -16),
        ])

        accessoryView = setupAccessoryView()

        colorSampler.delegate = self

        let searchSwipe = UIPanGestureRecognizer(target: self, action: #selector(showSearchGesture(_:)))
        toolbar.searchField.addGestureRecognizer(searchSwipe)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: NSNotification.Name.UIKeyboardWillHide,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: NSNotification.Name.UIKeyboardWillShow,
            object: nil)

        setTab(tabManager.lastTab())
    }

    var cardViewDefaultFrame: CGRect {
        return CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height// - Const.toolbarHeight
        )
    }

    @objc func tapToolbarPlaceholder() {
        toolbarManager.showToolbar(adjustScroll: true)
    }

    func setUpToolbar() -> BrowserToolbarView {
        let toolbar = BrowserToolbarView(
            frame: CGRect(x: 0, y: 0, width: cardView.frame.width, height: Const.toolbarHeight)
        )

        toolbar.searchField.setAction({ self.displaySearch() })
        toolbar.backButton.setAction(goBack)
        toolbar.stopButton.setAction(stop)
//        toolbar.tabButton.setAction(displayHistory)
        toolbar.tabButton.setAction(displayShareSheet)
        toolbar.tintColor = .darkText
        return toolbar
    }

    func prepareToShowSearch() {
        searchVC.setBackground(toolbar.backgroundColor)
        searchVC.browserVC = self
        searchVC.transition.direction = .present
        cardView.addSubview(searchVC.view)
    }

    var isDisplayingSearch: Bool {
        return searchVC.view.superview == cardView
    }

    func displaySearch(isInstant: Bool = false) {
        prepareToShowSearch()
        searchVC.transition.isPreExpanded = isInstant
        searchVC.transition.animateTransition(searchVC: searchVC, browserVC: self, completion: {
            self.searchVC.transition.isPreExpanded = false
        })
    }

    @objc func showSearchGesture(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            prepareToShowSearch()
            searchVC.transition.showKeyboard = false
            searchVC.transition.animateTransition(searchVC: searchVC, browserVC: self) {
                self.searchVC.transition.showKeyboard = true
            }
        }
        searchVC.handleEntrancePan(gesture)
    }

    func stop() {
        webView.stopLoading()
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else if let parent = currentTab?.parentTab {
            setTab(parent)
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

    override func viewWillAppear(_ animated: Bool) {
        toolbarManager.showToolbar(animated: false)
        statusBar.backgroundView.alpha = 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        toolbarManager.hideToolbar()
    }

    override func viewDidAppear(_ animated: Bool) {
//        webView.scrollView.contentInset = .zero
        self.setNeedsStatusBarAppearanceUpdate()

        self.colorSampler.startUpdates()
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

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Actions    

    @objc func copyURL() {
        UIPasteboard.general.string = self.editableLocation
    }

    // MARK: - Share ActivityViewController and 1Password

    @objc func displayShareSheet() {
        let avc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        avc.view.tintColor = UIColor.label
        
        avc.addAction(UIAlertAction.init(title: "Copy URL", style: .default, handler: { _ in
            self.copyURL()
        }))
        avc.addAction(UIAlertAction.init(title: "Share", style: .default, handler: { _ in
//            self.resignFirstResponder() // without this, action sheet dismiss animation won't go all the way
            self.makeShareSheet { avc in
                self.present(avc, animated: true, completion: nil)
            }
        }))
        avc.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))
        present(avc, animated: true, completion: nil)
    }

    // MARK: - Webview State

    func navigateTo(_ url: URL) {
        errorView?.removeFromSuperview()
        toolbar.text = url.displayHost
        setProgressView(0)

        let nav = webView.load(URLRequest(url: url))
        
        toolbar.backgroundColor = .black
        statusBar.backgroundColor = .black
        setNeedsStatusBarAppearanceUpdate()
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
        guard let errorLabel = errorView.subviews.first as? UILabel else { return }

        errorView.backgroundColor = toolbar.backgroundColor
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

    func updateLoadingState(estimatedProgress: CGFloat? = nil) {
        guard isViewLoaded else { return }
        assert(webView != nil, "nil webview")

        searchVC.hasDraftLocation = false
        toolbar.text = self.displayLocation

        if self.webView.isLoading {
            toolbarManager.showToolbar()
        }
        
        if let progress = estimatedProgress {
            setProgressView(Float(progress))
        }

        toolbar.isLoading = webView.isLoading
        toolbar.isSecure = webView.hasOnlySecureContent
        toolbar.isSearch = isSearching || isBlank
        
        if !webView.isLoading && progressView.alpha > 0 {
            setProgressView(1)
        }

        HistoryManager.shared.sync(
            tab: currentTab!,
            with: webView.backForwardList
        )
        
        colorSampler.updateColors()
    }
    
    private var lastProgress: Float = 0
    func setProgressView(_ newValue: Float) {
        if progressView.alpha == 0 && newValue < 1 {
            UIView.animate(withDuration: 0.2) {
                self.progressView.alpha = 1
            }
        }
        progressView.setProgress(newValue, animated: newValue > lastProgress)
        if newValue == 1 {
            UIView.animate(withDuration: 0.2, delay: 0.3, options: .curveEaseInOut, animations: {
                self.progressView.alpha = 0
            }, completion: { _ in
                self.progressView.setProgress(0, animated: false)
            })
        }
        
        lastProgress = newValue
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

extension BrowserViewController: UIActivityItemSource {
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
        })
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return self.webView!.url!
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivityType?) -> Any? {
        if OnePasswordExtension.shared().isOnePasswordExtensionActivityType(activityType?.rawValue) {
            // Return the 1Password extension item
            return self.onePasswordExtensionItem
        } else {
            // Return the current URL
            return self.webView!.url!
        }
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                dataTypeIdentifierForActivityType activityType: UIActivityType?) -> String {
        // Because of our UTI declaration, this UTI now satisfies
        // both the 1Password Extension and the usual NSURL for Share extensions.
        return "org.appextension.fill-browser-action"
    }

    func makeShareSheet(completion: @escaping (UIActivityViewController) -> Void) {
        if webView.url == nil { return }

        let onePass = OnePasswordExtension.shared()

        onePass.createExtensionItem(
            forWebView: self.webView,
            completion: { (extensionItem, error) in
                if extensionItem == nil {
                    print("Failed to create an extension item: \(String(describing: error))")
                    return
                }
                self.onePasswordExtensionItem = extensionItem

                let activityItems: [Any] = [self, self.webView.url!]
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
}

extension BrowserViewController: WebviewColorSamplerDelegate {

    var sampledWebView: WKWebView {
        return webView
    }

    var shouldUpdateSample: Bool {
        return isViewLoaded
            && view.window != nil
            && UIApplication.shared.applicationState == .active
            && webView != nil
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        guard let keyboardFrame: NSValue = userInfo.value(
            forKey: UIKeyboardFrameEndUserInfoKey) as? NSValue else { return }
        let keyboardRectangle = keyboardFrame.cgRectValue
        let newHeight = keyboardRectangle.height

        // Hack to prevent accessory of showing up at bottom
        accessoryHeightConstraint?.constant = newHeight < 50 ? 0 : 48
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        // Hack to prevent accessory of showing up at bottom
        accessoryHeightConstraint?.constant = 0
    }

    func topColorChange(_ newColor: UIColor, offset: CGPoint) {
        if webView.scrollView.isOverScrolledTop {
            return
        }

        if webView.scrollView.isAtTop {
            topOverscrollCover.backgroundColor = newColor
        }
        
        if shouldUpdateSample {
            currentTab?.currentVisit?.topColor = newColor
//            toolbar.transitionBackground(to: newColor, from: .bottomToTop)
            statusBar.transitionBackground(to: newColor, from: .bottomToTop)
//            UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState], animations: {
//                self.setNeedsStatusBarAppearanceUpdate()
//            })
            progressView.tintColor = newColor.isLight ? .white : .darkText
            if !webView.scrollView.isTracking && !webView.scrollView.isDecelerating {
                toolbarManager.updateStatusBarColor()
            }
        }
    }

    func bottomColorChange(_ newColor: UIColor, offset: CGPoint) {
        
        if webView.scrollView.isOverScrolledBottom {
            return
        }
        bottomOverscrollCover.backgroundColor = newColor
        
        if shouldUpdateSample {
            currentTab?.currentVisit?.bottomColor = newColor
            toolbar.transitionBackground(to: newColor, from: .topToBottom)
            
//            toolbar.searchField.backgroundColor = newColor
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear

        }
    }
    
    func fixedPositionDidChange(_ result: FixedNavResult) {
        UIView.animate(withDuration: 0.3) {
            self.statusBar.backgroundView.alpha = result.hasTopNav ? 1 : 0
            self.topOverscrollCover.alpha = result.hasTopNav ? 0 : 1
//            self.bottomOverscrollCover.alpha = result.hasBottomNav ? 0 : 1
        }
        if result.hasBottomNav && !isShowingToolbar {
            toolbarManager.showToolbar()
        }
    }

    func cancelColorChange() {
        statusBar.cancelColorChange()
        toolbar.cancelColorChange()
    }
}
