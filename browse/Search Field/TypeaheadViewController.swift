//
//  TypeaheadViewController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

let typeaheadReuseID = "TypeaheadRow"
let MAX_ROWS : Int = 4
let SEARCHVIEW_MAX_H : CGFloat = 160.0

struct TypeaheadRow {
    let text: String
    let action: (() -> Void)?
    let isEnabled: Bool = true
}

class TypeaheadViewController: UIViewController {

    var contentView: UIView!
    var backgroundView: PlainBlurView!
    var scrim: UIView!
    var textView: UITextView!
    var cancel: ToolbarTextButton!
    var suggestionTable: UITableView!
    var keyboardPlaceholder: UIImageView!
    
    var keyboardSnapshot: UIImage?
    
    var isDismissing = false

    var displaySearchTransition = TypeaheadAnimationController()
    
    var kbHeightConstraint : NSLayoutConstraint!
    var suggestHeightConstraint : NSLayoutConstraint!
    var textHeightConstraint : NSLayoutConstraint!
    var toolbarBottomMargin : NSLayoutConstraint!

    var textHeight : CGFloat = 12
    var suggestionSpacer : CGFloat = 24
    var suggestionHeight : CGFloat = 24
    var keyboardHeight : CGFloat = 250
    var showingCancel = true
    
    var suggestions : [TypeaheadRow] = []
    
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
    var pageActions : [TypeaheadRow] {
        return [
        TypeaheadRow(text: browser?.webView.title ?? "Untitled Page", action: {
            guard let b = self.browser else { return }
            self.dismiss(animated: true, completion: { b.webView.reload() })
        }),
        TypeaheadRow(text: "Share", action: {
            guard let b = self.browser else { return }
            b.makeShareSheet { avc in
                self.present(avc, animated: true, completion: nil)
            }
        }),
        TypeaheadRow(text: "Paste and go", action: {
            guard let b = self.browser else { return }
            if let str = UIPasteboard.general.string {
                self.textView.text = str
                b.navigateToText(str)
            }
            self.dismiss(animated: true)
        }),
        TypeaheadRow(text: "Copy", action: {
            guard let b = self.browser else { return }
            self.dismiss(animated: true, completion: {
                b.copyURL()
                let alert = UIAlertController(title: "Copied", message: nil, preferredStyle: .alert)
                b.present(alert, animated: true, completion: {
                    alert.dismiss(animated: true, completion: nil)
                })
            })
        }),
        ]
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

        contentView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(verticalPan(gesture:)))
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
        contentView.addSubview(suggestionTable)

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
        maskView.bounds.size.height = SEARCHVIEW_MAX_H
        textView.mask = maskView
        
        cancel = ToolbarTextButton(title: "Cancel", withIcon: nil, onTap: dismissSelf)
        cancel.size = .medium
        cancel.sizeToFit()
        cancel.translatesAutoresizingMaskIntoConstraints = false

        keyboardPlaceholder = UIImageView()
        keyboardPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        keyboardPlaceholder.contentMode = .top
        contentView.addSubview(keyboardPlaceholder)
        
        if (showingCancel) {
            contentView.addSubview(cancel)

            cancel.bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: -12).isActive = true
            cancel.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            cancel.widthAnchor.constraint(equalToConstant: cancel.bounds.width).isActive = true
            cancel.heightAnchor.constraint(equalToConstant: cancel.bounds.height).isActive = true

            textView.rightAnchor.constraint(equalTo: cancel.leftAnchor).isActive = true
        }
        else {
            contentView.rightAnchor.constraint(equalTo: textView.rightAnchor).isActive = true
        }

        textView.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 36)
        textHeightConstraint.isActive = true
                
        suggestionTable.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        suggestionTable.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        suggestionTable.bottomAnchor.constraint(equalTo: textView.topAnchor, constant: -8).isActive = true
        suggestionTable.heightAnchor.constraint(equalToConstant: suggestionTable.rowHeight * 4).isActive = true
        
        suggestHeightConstraint = textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: suggestionSpacer)
        suggestHeightConstraint.isActive = true
        
        keyboardPlaceholder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        keyboardPlaceholder.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        keyboardPlaceholder.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        
        toolbarBottomMargin = keyboardPlaceholder.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: KB_MARGIN)
        toolbarBottomMargin.isActive = true
        kbHeightConstraint = keyboardPlaceholder.heightAnchor.constraint(equalToConstant: 0)
        kbHeightConstraint.isActive = true

        NotificationCenter.default.addObserver(self, selector: #selector(updateKeyboardHeight), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateKeyboardHeight), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        
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
            updateTextViewSize()
            showPageActions()
        }
        
        keyboardPlaceholder.image = nil
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
        
        if textView.isFirstResponder && !kbHeightConstraint.isPopAnimating && !isDismissing {
            kbHeightConstraint.constant = keyboardHeight
        }
    }
}
    
extension TypeaheadViewController : UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateTextViewSize()
        updateSuggestion(for: textView.text)
    }
    
    func updateSuggestion(for text: String) {
        guard text != "" else {
            self.suggestions = []
            self.renderSuggestions()
            return
        }
        let suggestionsForText = textView.text
        Typeahead.shared.suggestions(for: textView.text, maxCount: 4) { arr in
            // If text has changed since return, don't bother
            guard self.textView.text == suggestionsForText else { return }
            
            self.suggestions = arr.reversed().map({ txt in
                return TypeaheadRow(text: txt, action: nil)
            })
            self.renderSuggestions()
        }
    }
    
    func showPageActions() {
        suggestions = pageActions
        renderSuggestions()
    }
    
    func displayShare() {
    }
    
    func renderSuggestions() {
        var suggestionH : CGFloat = 0
        for index in 0..<suggestions.count {
             suggestionH += tableView(
                suggestionTable,
                heightForRowAt: IndexPath(row: index, section: 0))
        }
        
        suggestionHeight = suggestionH + suggestionSpacer
        suggestHeightConstraint.constant = suggestionHeight
        suggestionTable.reloadData()
        suggestionTable.layoutIfNeeded()
    }
    
    func updateTextViewSize() {
        let fixedWidth = textView.frame.size.width
//        textView.textContainerInset = UIEdgeInsetsMake(10, 12, 10, 12)
        textView.textContainerInset = UIEdgeInsetsMake(10, 20, 22, 0)
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        textHeight = max(20, min(fullTextSize.height, SEARCHVIEW_MAX_H))
        textHeightConstraint.constant = textHeight
        
        textView.mask?.frame.size.width = textView.bounds.width
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            navigateTo(textView.text)
            return false
        }
        return true
    }
    
    func navigateTo(_ text: String) {
        if let browser = self.browser {
            browser.navigateToText(text)
            dismissSelf()
            return
        }
        if let switcher = self.switcher {
            self.dismiss(animated: true, completion: {
                switcher.addTab(startingFrom: text)
            })
            return
        }
    }
}

extension TypeaheadViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = suggestions[indexPath.item]
        if let action = row.action { action() }
        else { navigateTo(row.text) }
    }
}

extension TypeaheadViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(MAX_ROWS, suggestions.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: typeaheadReuseID, for: indexPath) as! TypeaheadCell
        // Configure the cells
        
        cell.textLabel?.text = suggestions[indexPath.item].text
        if suggestions[indexPath.item].action != nil && indexPath.item == 0 {
            cell.isTitle = true
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let text = suggestions[indexPath.item].text
        if text.count > 60 {
            return 96.0
        }
        return 48.0
    }
}

// MARK - Gesture

let KB_MARGIN : CGFloat = 0
let SPACE_FOR_INDICATOR : CGFloat = 24

extension TypeaheadViewController : UIGestureRecognizerDelegate {
    @objc func verticalPan(gesture: UIPanGestureRecognizer) {
        let dist = gesture.translation(in: view)
        let vel = gesture.velocity(in: view)

        if gesture.state == .began {
            showFakeKeyboard()
            isDismissing = true
            textView.isScrollEnabled = true
        }
        else if gesture.state == .changed {
            if dist.y < 0 {
                kbHeightConstraint.constant = keyboardHeight
                suggestHeightConstraint.constant = suggestionHeight + 0.4 * elasticLimit(-dist.y)
            }
            else {
                if dist.y < keyboardHeight {
                    kbHeightConstraint.constant = keyboardHeight - dist.y
                    
                    let progress =  dist.y.progress(from: 0, to: keyboardHeight).clip()
                    let margin = progress.blend(from: KB_MARGIN, to: SPACE_FOR_INDICATOR)
//                    let textAdjust = progress.blend(from: 0, to: SPACE_FOR_INDICATOR - KB_MARGIN )
                    toolbarBottomMargin.constant = margin
//                    textHeightConstraint.constant = textHeight - textAdjust
                    suggestHeightConstraint.constant = suggestionHeight
                }
                else {
//                    toolbarBottomMargin.constant = SPACE_FOR_INDICATOR
                    kbHeightConstraint.constant = 0
                    suggestHeightConstraint.constant = suggestionHeight - dist.y + keyboardHeight
                }
                suggestionTable.alpha = dist.y.progress(from: keyboardHeight, to: keyboardHeight + 100).clip().reverse()
            }
        }
        else if gesture.state == .ended || gesture.state == .cancelled {
            isDismissing = false
            if (vel.y > 100 || kbHeightConstraint.constant < 100) && showingCancel {
                dismissSelf()
            }
            else {
                kbHeightConstraint.springConstant(to: keyboardHeight) {_,_ in
                    self.showRealKeyboard()
                    self.textView.isScrollEnabled = false
                }
                suggestHeightConstraint.springConstant(to: suggestionHeight)
                toolbarBottomMargin.springConstant(to: KB_MARGIN)
                suggestionTable.alpha = 1
                textHeightConstraint.springConstant(to: textHeight)
            }
        }
    }
    
    func showFakeKeyboard() {
        keyboardPlaceholder.isHidden = false
        keyboardPlaceholder.image = keyboardSnapshot
        UIView.setAnimationsEnabled(false)
        textView.resignFirstResponder()
        UIView.setAnimationsEnabled(true)
        
    }
    func showRealKeyboard() {
        keyboardPlaceholder.isHidden = true
        UIView.setAnimationsEnabled(false)
        textView.becomeFirstResponder()
        UIView.setAnimationsEnabled(true)
    }
    
    @objc func updateKeyboardSnapshot() {
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
                window.drawHierarchy(in: window.frame, afterScreenUpdates: true)
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        return img
    }
}


// MARK - Animation

extension TypeaheadViewController : UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        displaySearchTransition.direction = .present
        return displaySearchTransition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        displaySearchTransition.direction = .dismiss
        return displaySearchTransition
    }
}

