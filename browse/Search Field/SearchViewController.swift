//
//  SearchViewController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import pop

let typeaheadReuseID = "TypeaheadRow"
let MAX_ROWS : Int = 4
let SEARCHVIEW_MAX_H : CGFloat = 240.0

class SearchViewController: UIViewController {

    var contentView: UIView!
    var backgroundView: PlainBlurView!
    var scrim: UIView!
    var textView: UITextView!
    var cancel: ToolbarTextButton!
    var suggestionTable: UITableView!
    var keyboardPlaceholder: UIImageView!
    var pageActionView: PageActionView!
    
    var keyboardSnapshot: UIImage?
    
    var isTransitioning = false

    var displaySearchTransition = SearchTransitionController()
    
    var kbHeightConstraint : NSLayoutConstraint!
    var suggestionHeightConstraint : NSLayoutConstraint!
    var contextAreaHeightConstraint : NSLayoutConstraint!
    var textHeightConstraint : NSLayoutConstraint!
    var toolbarBottomMargin : NSLayoutConstraint!
    var actionsHeight : NSLayoutConstraint!

    var textHeight : CGFloat = 12
    var suggestionSpacer : CGFloat = 24
    var contextAreaHeight: CGFloat = 24
    var keyboardHeight : CGFloat = 250
    var showingCancel = true
    
    var suggestions : [TypeaheadSuggestion] = []
    
    var defaultBackground: UIColor = .black
    
    var browser : BrowserViewController? {
        return self.presentingViewController as? BrowserViewController
    }
    var switcher : TabSwitcherViewController? {
        if let nav = self.presentingViewController as? UINavigationController,
            let switcher = nav.topViewController as? TabSwitcherViewController {
            return switcher
        }
        else { return nil }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        scrim = UIView(frame: view.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrim)

        if (showingCancel) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
            scrim.addGestureRecognizer(tap)
        }
        
        contentView = UIView(frame: view.bounds)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.tintColor = .darkText
        contentView.clipsToBounds = true
        contentView.radius = 12
        view.addSubview(contentView)
        
        backgroundView = PlainBlurView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.overlayAlpha = 0.8
        contentView.addSubview(backgroundView)

        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(handleDimissPan(_:)))
        dismissPanner.cancelsTouchesInView = true
        dismissPanner.delaysTouchesBegan = false
        view.addGestureRecognizer(dismissPanner)
        
        suggestionTable = UITableView(frame:self.view.frame)
        suggestionTable.rowHeight = 48.0
        suggestionTable.register(TypeaheadCell.self, forCellReuseIdentifier: typeaheadReuseID)
        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.dataSource = self
        suggestionTable.delegate = self
        suggestionTable.isScrollEnabled = false
        suggestionTable.separatorStyle = .none
        suggestionTable.backgroundColor = .clear
        suggestionTable.backgroundView?.backgroundColor = .clear

//        textView = SearchTextView()
        textView = UITextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        textView.font = .systemFont(ofSize: 18)
        //UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 18)
        textView.text = ""
        textView.placeholder = "Where to?"
        textView.delegate = self
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear //UIColor.white.withAlphaComponent(0.3)
//        textView.radius = SEARCH_RADIUS
        textView.textColor = .darkText
        textView.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = .light
        textView.enablesReturnKeyAutomatically = true
        textView.keyboardType = .webSearch
        textView.returnKeyType = .go
        textView.autocorrectionType = .no
        textView.translatesAutoresizingMaskIntoConstraints = false
//        textView.backgroundColor = .red
        contentView.addSubview(textView)
        
        let maskView = UIView(frame: textView.bounds)
        maskView.backgroundColor = .red
        maskView.frame = textView.bounds
        maskView.frame.size.height = 500 // TODO Large number because mask is scrollable :(
        textView.mask = maskView
        
        cancel = ToolbarTextButton(title: "Cancel", withIcon: nil, onTap: dismissSelf)
        cancel.size = .medium
        cancel.sizeToFit()
        cancel.translatesAutoresizingMaskIntoConstraints = false

        keyboardPlaceholder = UIImageView()
        keyboardPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        keyboardPlaceholder.contentMode = .top
        contentView.addSubview(keyboardPlaceholder)
        
        pageActionView = PageActionView()
        pageActionView.delegate = self
        
        contextAreaHeightConstraint = textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: suggestionSpacer)
        suggestionHeightConstraint = suggestionTable.heightAnchor.constraint(equalToConstant: suggestionTable.rowHeight * 4)
        actionsHeight = pageActionView.heightAnchor.constraint(equalToConstant: 0)
        contentView.addSubview(suggestionTable, constraints: [
            contextAreaHeightConstraint,
            suggestionHeightConstraint,
            suggestionTable.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            suggestionTable.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            suggestionTable.bottomAnchor.constraint(equalTo: textView.topAnchor, constant: -8),
        ])
        contentView.addSubview(pageActionView, constraints: [
            actionsHeight,
            pageActionView.bottomAnchor.constraint(equalTo: textView.topAnchor),
            pageActionView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
            pageActionView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
        ])

        textView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor).isActive = true

        if (showingCancel) {
            contentView.addSubview(cancel, constraints: [
                cancel.bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: -12),
                cancel.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
                cancel.widthAnchor.constraint(equalToConstant: cancel.bounds.width),
                cancel.heightAnchor.constraint(equalToConstant: cancel.bounds.height),
            ])
        }
        
        textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 36)
        toolbarBottomMargin = keyboardPlaceholder.topAnchor.constraint(equalTo: textView.bottomAnchor)
        kbHeightConstraint = keyboardPlaceholder.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            toolbarBottomMargin,
            textHeightConstraint,
            textView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
            
            // Keyboard
            kbHeightConstraint,
            keyboardPlaceholder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            keyboardPlaceholder.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            keyboardPlaceholder.rightAnchor.constraint(equalTo: contentView.rightAnchor),
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateKeyboardHeight),
                                               name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateKeyboardHeight),
                                               name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)

        setBackground(defaultBackground)
        updateTextViewSize()
        view.layoutIfNeeded()
    }
    
    func setBackground(_ newColor: UIColor) {
        guard isViewLoaded else {
            defaultBackground = newColor
            return
        }
        
        let darkContent = !newColor.isLight
//        contentView.backgroundColor = newColor.withAlphaComponent(0.8)
        backgroundView.overlayColor = newColor
        
//        scrim.backgroundColor = newColor.withAlphaComponent(0.6)
        view.tintColor = darkContent ? .darkText : .white
        contentView.tintColor = view.tintColor
        textView.textColor = view.tintColor
//        textView.backgroundColor = darkContent ? UIColor.black.withAlphaComponent(0.1) : UIColor.white.withAlphaComponent(0.3)
        textView.placeholderColor = darkContent ? UIColor.black.withAlphaComponent(0.4) : UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = darkContent ? .light : .dark
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (ctx) in
            //
        }) { (ctx) in
            self.updateKeyboardSnapshot()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // TODO: Why?
        view.frame = UIScreen.main.bounds
        
        if let browser = self.browser {
            textView.text = browser.editableLocation
            pageActionView.title = browser.webView.title
            pageActionView.isBookmarked = false
            pageActionView.isBookmarkEnabled = BookmarkProvider.shared.isLoggedIn
            
            BookmarkProvider.shared.isBookmarked(browser.webView.url) { isBookmarked in
                self.pageActionView.isBookmarked = isBookmarked
            }
            updateTextViewSize()
            updateSuggestion(for: textView.text)
        }
        
//        keybsoardPlaceholder.image = nil
    }
    
    func focusTextView() {
        textView.becomeFirstResponder()
        textView.selectAll(nil) // if not nil, will show actions
    }
    
    override func viewDidAppear(_ animated: Bool) {
        updateKeyboardSnapshot()
    }
    
    @objc
    func dismissSelf() {
        showFakeKeyboard()
        self.dismiss(animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @objc func updateKeyboardHeight(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame: NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        keyboardHeight = keyboardRectangle.height// + 12
        
        if textView.isFirstResponder && !kbHeightConstraint.isPopAnimating && !isTransitioning {
            kbHeightConstraint.constant = keyboardHeight
        }
    }
}
    
extension SearchViewController : UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateTextViewSize()
        updateSuggestion(for: textView.text)
    }
    
    func updateSuggestion(for text: String) {
        if shouldShowActions || text == "" {
            suggestions = []
            self.renderSuggestions()
            return
        }
        
        let suggestionsForText = textView.text
        Typeahead.shared.suggestions(for: textView.text, maxCount: 4) { arr in
            // If text has changed since return, don't bother
            guard self.textView.text == suggestionsForText else { return }
            
            self.suggestions = arr.reversed()
            self.renderSuggestions()
        }
    }
    
    var shouldShowActions : Bool {
        return browser?.editableLocation == textView.text || (browser != nil && textView.text == "")
    }
    
    func renderSuggestions() {
        if shouldShowActions  {
            contextAreaHeight = 100
            actionsHeight.constant = contextAreaHeight
            contextAreaHeightConstraint.constant = contextAreaHeight
        }
        else {
            actionsHeight.constant = 0
            var suggestionH : CGFloat = 0
            for index in 0..<suggestions.count {
                suggestionH += tableView(
                    suggestionTable,
                    heightForRowAt: IndexPath(row: index, section: 0))
            }
            contextAreaHeight = suggestionH + suggestionSpacer
            suggestionHeightConstraint.constant = suggestionH
        }

        contextAreaHeightConstraint.springConstant(to: contextAreaHeight)
        suggestionTable.reloadData()
        suggestionTable.layoutIfNeeded()
    }
    
    func updateTextViewSize() {
        let fixedWidth = textView.frame.size.width
//        textView.textContainerInset = UIEdgeInsetsMake(10, 12, 10, 12)
        textView.textContainerInset = UIEdgeInsetsMake(10, 20, 22, showingCancel ? cancel.bounds.width : 0 )
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        textHeight = max(20, min(fullTextSize.height, SEARCHVIEW_MAX_H))
        textHeightConstraint.constant = textHeight
        
        textView.mask?.frame.size.width = textView.bounds.width
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n", let entry = textView.text {
            if entry.isProbablyURL {
                var url : URL?
                if (text.hasPrefix("http://") || text.hasPrefix("https://")) {
                    url = URL(string: text)
                }
                else {
                    url = URL(string: "http://" + text)
                }
                if let url = url {
                    navigateTo(url)
                    return false
                }
            }
            
            let url = Typeahead.shared.serpURLfor(entry)!
            navigateTo(url)
            return false
        }
        return true
    }
    
    func navigateTo(_ url: URL) {
        if let browser = self.browser {
            browser.navigateTo(url)
            dismissSelf()
            return
        }
        if let switcher = self.switcher {
            self.dismiss(animated: true, completion: {
                switcher.addTab(startingFrom: url)
            })
            return
        }
    }
}

extension SearchViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = suggestions[indexPath.item]
        if let url = row.url { navigateTo(url) }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let row = suggestions[indexPath.item]
        return row.url != nil
    }
}

extension SearchViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(MAX_ROWS, suggestions.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: typeaheadReuseID, for: indexPath) as! TypeaheadCell
        // Configure the cells
        
        let suggestion = suggestions[indexPath.item]
        cell.textLabel?.text = suggestion.title
        cell.detailTextLabel?.text = suggestion.detail
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let text = suggestions[indexPath.item].title
        if text.count > 60 {
            return 96.0
        }
        return 48.0
    }
}

// MARK - Gesture

let SPACE_FOR_INDICATOR : CGFloat = 26

extension SearchViewController : UIGestureRecognizerDelegate {
    private func verticalPan(gesture: UIPanGestureRecognizer, isEntrance: Bool = false) {
        guard showingCancel else { return }

        var dist = gesture.translation(in: view)
        let vel = gesture.velocity(in: view)
        
        if isEntrance {
            dist.y += keyboardHeight
        }

        if gesture.state == .began {
            showFakeKeyboard()
            isTransitioning = true
        }
        else if gesture.state == .changed {
            if dist.y < 0 {
                kbHeightConstraint.constant = keyboardHeight
                textHeightConstraint.constant = textHeight + 0.4 * elasticLimit(-dist.y)
            }
            else {
                if dist.y < keyboardHeight {
                    kbHeightConstraint.constant = keyboardHeight - dist.y
                    let progress = dist.y.progress(from: 0, to: keyboardHeight).clip()
                    let margin = progress.blend(from: 0, to: SPACE_FOR_INDICATOR)
                    toolbarBottomMargin.constant = margin
                    contextAreaHeightConstraint.constant = contextAreaHeight
                }
                else {
                    kbHeightConstraint.constant = 0
                    contextAreaHeightConstraint.constant = contextAreaHeight - elasticLimit(dist.y - keyboardHeight)
                }
                suggestionTable.alpha = dist.y.progress(from: keyboardHeight - 40, to: keyboardHeight + 100).clip().reverse()
                pageActionView.alpha = dist.y.progress(from: keyboardHeight - 40, to: keyboardHeight + 60).clip().reverse()
            }
        }
        else if gesture.state == .ended || gesture.state == .cancelled {
            isTransitioning = false
            if (vel.y > 100 || kbHeightConstraint.constant < 100) && showingCancel {
                dismissSelf()
            }
            else {
                func finish() {
                    self.showRealKeyboard()
                    self.updateTextViewSize() // maybe reenable scrolls
                }
                let fromBelow = kbHeightConstraint.constant < keyboardHeight
                kbHeightConstraint.springConstant(to: keyboardHeight) {_,_ in
                    if fromBelow { finish() }
                }
                contextAreaHeightConstraint.springConstant(to: contextAreaHeight)
                toolbarBottomMargin.springConstant(to: 0)
                suggestionTable.alpha = 1
                pageActionView.alpha = 1
                let ta = textHeightConstraint.springConstant(to: textHeight) {
                    _,_ in
                    if !fromBelow { finish() }
                }
                ta?.clampMode = POPAnimationClampFlags.both.rawValue // prevent flickering when textfield too small
            }
        }
    }
    
    @objc func handleDimissPan(_ gesture: UIPanGestureRecognizer) {
        verticalPan(gesture: gesture, isEntrance: false)
    }
    
    func handleEntrancePan(_ gesture: UIPanGestureRecognizer) {
        isTransitioning = true
        verticalPan(gesture: gesture, isEntrance: true)
    }
    
    func showFakeKeyboard() {
        keyboardPlaceholder.isHidden = false
        keyboardPlaceholder.image = keyboardSnapshot
        UIView.setAnimationsEnabled(false)
        textView.resignFirstResponder()
        UIView.setAnimationsEnabled(true)
        
        // shrink height to snapshot (in case was showing emoji etc)
        if let snapH = keyboardPlaceholder.image?.size.height, snapH < kbHeightConstraint.constant {
            keyboardHeight = snapH
            kbHeightConstraint.constant = snapH
        }
    }
    
    func showRealKeyboard() {
        keyboardPlaceholder.isHidden = true
        UIView.setAnimationsEnabled(false)
        textView.becomeFirstResponder()
        UIView.setAnimationsEnabled(true)
    }
    
    @objc func updateKeyboardSnapshot() {
        if !textView.isFirstResponder { return }
        keyboardSnapshot = takeKeyboardSnapshot()
    }
    
    func takeKeyboardSnapshot() -> UIImage? {
        let size = UIScreen.main.bounds.size
        let kbSize = CGSize(width: size.width, height: keyboardHeight)
        
        UIGraphicsBeginImageContextWithOptions(kbSize, false, 0)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.translateBy(x: 0, y: -(size.height - keyboardHeight))
        
        for window in UIApplication.shared.windows {
            if (window.screen == UIScreen.main) {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false) // if true, weird flicker
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK - Actions
extension SearchViewController : PageActionHandler {
    func refresh() {
        browser?.webView.reload()
    }
    
    func bookmark() {
        //
        if !BookmarkProvider.shared.isLoggedIn {
            func success() {
                DispatchQueue.main.async {
                    self.pageActionView.isBookmarkEnabled = true
                }
            }
            func tryAgain() {
                DispatchQueue.main.async {
                    let prompt = PinboardLoginController(success: success, failure: tryAgain)
                    prompt.message = "⚠️ That didn't seem to work"
                    prompt.view.setNeedsDisplay()
                    self.present(prompt, animated: true)
                }
            }
            let prompt = PinboardLoginController(success: success, failure: tryAgain)
            DispatchQueue.main.async {
                self.present(prompt, animated: true)
            }
        }
        else if !pageActionView.isBookmarked {
            guard let url = browser?.webView.url, let title = browser?.webView.title else { return }
            BookmarkProvider.shared.addBookmark(url, title: title) { isBookmarked in
                if isBookmarked { self.pageActionView.isBookmarked = true }
            }
        }
        else if pageActionView.isBookmarked {
//            BookmarkProvider.shared.add(browser?.webView.url)
            let options = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            options.addAction(UIAlertAction(title: "Edit", style: .default, handler: nil))
            options.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { _ in
                guard let url = self.browser?.webView.url else { return }
                BookmarkProvider.shared.removeBookmark(url) { isRemoved in
                    if isRemoved { self.pageActionView.isBookmarked = false }
                }
                self.showRealKeyboard()
            }))
            options.addAction(UIAlertAction(title: "Log Out", style: .default, handler: { _ in
                BookmarkProvider.shared.logOut()
                self.pageActionView.isBookmarkEnabled = false
                self.pageActionView.isBookmarked = false
                self.showRealKeyboard()
            }))
            options.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                self.showRealKeyboard()
            }))
            DispatchQueue.main.async {
                self.showFakeKeyboard()
                self.present(options, animated: true)
            }
        }
    }
    
    func share() {
        browser?.makeShareSheet { avc in
            self.showFakeKeyboard()
            avc.completionWithItemsHandler = { _, _, _, _ in
                self.showRealKeyboard()
            }
            self.present(avc, animated: true, completion: nil)
        }
    }
    
    func copy() {
        let b = browser
        b?.copyURL()
        let alert = UIAlertController(title: "Copied", message: nil, preferredStyle: .alert)
        self.showFakeKeyboard()
        present(alert, animated: true, completion: {
            alert.dismiss(animated: true, completion: {
                self.showRealKeyboard()
            })
        })
    }
}



// MARK - Animation

extension SearchViewController : UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        displaySearchTransition.direction = .present
        return displaySearchTransition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        displaySearchTransition.direction = .dismiss
        return displaySearchTransition
    }
}

