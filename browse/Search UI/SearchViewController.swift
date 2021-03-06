//
//  SearchViewController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

let typeaheadReuseID = "TypeaheadRow"
let maxTypeaheadSuggestions: Int = 8
let maxTextFieldHeight: CGFloat = 240.0
let textFieldInsets = UIEdgeInsets(top: 11, left: 14, bottom: 12, right: 14)
let pageActionHeight: CGFloat = 100 //100

let textFieldInnerMargin: CGFloat = 20
let textFieldRoomForIcons: CGFloat = 68

let SHEET_TOP_HANDLE_MARGIN: CGFloat = 28
let TOOLBAR_TOP_MARGIN: CGFloat = 6


// https://medium.com/@nguyenminhphuc/how-to-pass-ui-events-through-views-in-ios-c1be9ab1626b
class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}

class SearchViewController: UIViewController {

    var contentView: UIView!
    var backgroundView: PlainBlurView!
    var shadowView: UIView!
    
    var scrim: UIView!
    var textView: UITextView!
    var textViewFill: UIView!
    let locationLabel = LocationLabel()
    
    var suggestionTable: UITableView!
    var dragHandle: UIView!
    var pageActionView: PageActionView!
    var keyboard = KeyboardManager()
    
    var isFakeSelected: Bool = false

    var baseSheetHeight: CGFloat {
        return min(UIScreen.main.bounds.height - 20, 640)
    }
    var minSheetHeight: CGFloat {
        return Const.toolbarHeight + SHEET_TOP_HANDLE_MARGIN
    }
    var minSheetHeightDragging: CGFloat {
        return Const.toolbarHeight + SHEET_TOP_HANDLE_MARGIN
    }

    
    var isTransitioning = false
    var isSwiping = false
    
    var hasDraftLocation = false

    var transition = SearchTransitionController()

    var sheetHeight: NSLayoutConstraint!
    var textHeightConstraint: NSLayoutConstraint!
    var textViewContainerHeightConstraint: NSLayoutConstraint!
    var textTopMarginConstraint: NSLayoutConstraint!
    var bottomAttachment: NSLayoutConstraint!

    var labelCenterConstraint: NSLayoutConstraint!
    var textCenterConstraint: NSLayoutConstraint!
    
    private var leftInsetConstraint: NSLayoutConstraint!
    private var rightInsetConstraint: NSLayoutConstraint!

    var textHeight: CGFloat = 40
    
    var iconEntranceProgress: CGFloat {
        get {
            return leftInsetConstraint.constant.progress(textFieldRoomForIcons, textFieldInnerMargin)
        }
        set {
            let margin = newValue.lerp(textFieldRoomForIcons, textFieldInnerMargin)
            leftInsetConstraint.constant = margin
            rightInsetConstraint.constant = -margin
        }
        
    }

    var suggestions: [TypeaheadSuggestion] = []

    var isFakeTab = false
    var defaultBackground: UIColor = .white //.black

    var browserVC: BrowserViewController?

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PassthroughView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // make sure fake kb is clipped when not aligned with screen
        view.radius = Const.cardRadius
        view.clipsToBounds = true

        scrim = UIView(frame: view.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.addSubview(scrim, constraints: [
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrim.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrim.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(animateToSheetHidden))
        scrim.addGestureRecognizer(tap)

        contentView = UIView(frame: view.bounds)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.tintColor = .darkText
        contentView.clipsToBounds = true
        contentView.radius = 20
        view.addSubview(contentView)
        
        shadowView = UIView(frame: view.bounds)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        let path = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 12)
        shadowView.layer.shadowPath = path.cgPath
        shadowView.layer.shadowOpacity = 0.12
        shadowView.layer.shadowRadius = 24
        view.insertSubview(shadowView, belowSubview: contentView)
        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadowView.heightAnchor.constraint(equalToConstant: 100),
        ])
        
        backgroundView = PlainBlurView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.overlayAlpha = 1//0.9
        contentView.addSubview(backgroundView)

        bottomAttachment = contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: SHEET_TOP_HANDLE_MARGIN)
        sheetHeight = contentView.heightAnchor.constraint(equalToConstant: baseSheetHeight)
        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            bottomAttachment,
            sheetHeight
        ])

        suggestionTable = createSuggestions()
        
        textViewFill = createTextViewFill()
        textView = createTextView()
        
        textViewFill.addSubview(textView)
        contentView.addSubview(textViewFill)

        setupActions()
        setupTextViewConstraints()
        setupDrag()
        setupPlaceholderIcons()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateKeyboardHeight),
            name: NSNotification.Name.UIKeyboardWillShow,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateKeyboardHeight),
            name: NSNotification.Name.UIKeyboardWillChangeFrame,
            object: nil)

        setBackground(defaultBackground)
        updateTextViewSize()
//        view.layoutIfNeeded()        
    }

    func setupActions() {
        pageActionView = PageActionView()
        pageActionView.delegate = self
        
        let suggestionHeightConstraint = suggestionTable.heightAnchor.constraint(
            equalToConstant: 500)
        contentView.addSubview(suggestionTable, constraints: [
            suggestionHeightConstraint,
            suggestionTable.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            suggestionTable.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            suggestionTable.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8)
        ])
    }

    func setupDrag() {
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(handleDimissPan(_:)))
        dismissPanner.cancelsTouchesInView = true
        dismissPanner.delaysTouchesBegan = false
        contentView.addGestureRecognizer(dismissPanner)

        dragHandle = UIView(frame: .zero)
        dragHandle.radius = 2
        contentView.addSubview(dragHandle, constraints: [
            dragHandle.heightAnchor.constraint(equalToConstant: 4),
            dragHandle.widthAnchor.constraint(equalToConstant: 32),
            dragHandle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            dragHandle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    func setupPlaceholderIcons() {
        let leftIcon = ToolbarIconButton(icon: UIImage(named: "back"))
        let rightIcon = ToolbarIconButton(icon: UIImage(named: "action"))
        
        contentView.addSubview(leftIcon, constraints: [
            leftIcon.rightAnchor.constraint(equalTo: textViewFill.leftAnchor),
            leftIcon.topAnchor.constraint(equalTo: textViewFill.topAnchor, constant: 0)
        ])
        contentView.addSubview(rightIcon, constraints: [
            rightIcon.leftAnchor.constraint(equalTo: textViewFill.rightAnchor),
            rightIcon.topAnchor.constraint(equalTo: textViewFill.topAnchor, constant: 0)
        ])
    }

    func setupTextViewConstraints() {
        textViewContainerHeightConstraint = textViewFill.heightAnchor.constraint(equalToConstant: 36)
        textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 36)
        textTopMarginConstraint = textViewFill.topAnchor.constraint(
            equalTo: contentView.topAnchor, constant: SHEET_TOP_HANDLE_MARGIN)
        
        leftInsetConstraint = textViewFill.leadingAnchor.constraint(
            equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 12)
        rightInsetConstraint = textViewFill.trailingAnchor.constraint(
            equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -12)

        labelCenterConstraint = locationLabel.centerXAnchor.constraint(equalTo: textViewFill.centerXAnchor)
        textCenterConstraint = textView.centerXAnchor.constraint(equalTo: textViewFill.centerXAnchor)
        
        textViewFill.addSubview(locationLabel, constraints: [
            labelCenterConstraint,
            locationLabel.topAnchor.constraint(equalTo: textViewFill.topAnchor, constant: 14),
            locationLabel.widthAnchor.constraint(lessThanOrEqualTo: textViewFill.widthAnchor, constant: -24)
        ])
        locationLabel.isUserInteractionEnabled = false
        
        NSLayoutConstraint.activate([
            textHeightConstraint,
            textViewContainerHeightConstraint,
            textTopMarginConstraint,
            leftInsetConstraint,
            rightInsetConstraint
        ])
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: textViewFill.topAnchor),
            textView.widthAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.widthAnchor,
                constant: -2 * textFieldInnerMargin),
            textCenterConstraint
        ])
    }
    
    func updateIconInset() {
        let pct = sheetHeight.constant.progress(Const.toolbarHeight, baseSheetHeight)
        iconEntranceProgress = pct
    }
    
    func createTextViewFill() -> UIView {
        let view = UIView()
        
        view.translatesAutoresizingMaskIntoConstraints = false
//        view.backgroundColor = .darkTouch
        view.radius = 12
        view.clipsToBounds = true
        
        return view
    }

    func createTextView() -> UITextView {
        let textView = UITextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        textView.font = Const.textFieldFont
        textView.text = ""
//        textView.placeholder = "Where to?"
        
        textView.delegate = self
        textView.isScrollEnabled = true
        
        textView.backgroundColor = .clear
        textView.textColor = .darkText
//        textView.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = .light
        
        textView.enablesReturnKeyAutomatically = true
        textView.keyboardType = .webSearch
        textView.returnKeyType = .go
        textView.autocorrectionType = .no
        
        let maskView = UIView(frame: textView.bounds)
        maskView.backgroundColor = .red
        maskView.frame = textView.bounds
        maskView.frame.size.height = 500 // TODO Large number because mask is scrollable :(
        textView.mask = maskView
        
        return textView
    }

    func createSuggestions() -> UITableView {
        let table = UITableView(frame: self.view.frame)
        table.rowHeight = 48.0
        table.register(TypeaheadCell.self, forCellReuseIdentifier: typeaheadReuseID)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.isScrollEnabled = false
        table.separatorStyle = .none
        table.backgroundColor = .clear
        table.backgroundView?.backgroundColor = .clear
        return table
    }

    func setBackground(_ newColor: UIColor) {
        guard isViewLoaded else {
            defaultBackground = newColor
            return
        }

        let isBackgroundLight = !newColor.isLight
        backgroundView.overlayColor = newColor
        view.tintColor = isBackgroundLight ? .darkText : .white
        
        contentView.tintColor = view.tintColor
        textView.textColor = view.tintColor
        dragHandle.backgroundColor = view.tintColor.withAlphaComponent(0.2)

//        textView.placeholderColor = isBackgroundLight
//            ? UIColor.black.withAlphaComponent(0.4)
//            : UIColor.white.withAlphaComponent(0.4)
        
        textViewFill.backgroundColor = isBackgroundLight
            ? .darkField
            : .lightField
//        textViewFill.backgroundColor = isBackgroundLight
//            ? .darkTouch
//            : .lightTouch

        textView.keyboardAppearance = isBackgroundLight ? .light : .dark
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
            //
        }, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        // TODO: Why?
        view.frame = UIScreen.main.bounds

        if let browser = browserVC, !hasDraftLocation {
            textView.text = browser.editableLocation
            
            locationLabel.text = browser.displayLocation
            locationLabel.showBrokenLock = !browser.toolbar.searchField.isSecure
            locationLabel.showSearch = browser.toolbar.searchField.isSearch

            pageActionView.title = browser.webView.title
            pageActionView.isBookmarked = false
            pageActionView.isBookmarkEnabled = BookmarkProvider.shared.isLoggedIn

            BookmarkProvider.shared.isBookmarked(browser.webView.url) { isBookmarked in
                self.pageActionView.isBookmarked = isBookmarked
            }
            updateTextViewSize()
            updateHighlight(textView)
            updateSuggestion(for: textView.text)
            suggestionTable.reloadData()
        }
    }

    func focusTextView() {
        textView.tintColor = .clear
        textView.becomeFirstResponder()
        textView.selectAll(nil)

//        textView.selectAll(nil) // if not nil, will show actions
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func updateKeyboardHeight(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardInfo = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey)
        guard let keyboardFrame: NSValue = keyboardInfo as? NSValue else { return }
        let keyboardRectangle = keyboardFrame.cgRectValue

        if keyboardRectangle.height < 10 {
            // thats not what we meant by keyboard height
            return
        }

        keyboard.height = keyboardRectangle.height
    }
}

extension SearchViewController: UITextViewDelegate {
    
    // When editing starts, select all and then make handles (and cursor) invisible

    func textViewDidChange(_ textView: UITextView) {
        updateFieldForNewText()
        updateSuggestion(for: textView.text)
//        updateBrowserOffset()
        
        if textView.tintColor == .clear {
            DispatchQueue.main.async {
                textView.tintColor = self.view.tintColor
            }
        }
    }
    
    
    
    func updateFieldForNewText() {
        updateHighlight(textView)
        updateTextViewSize()
        updateLabel()
    }

    func updateHighlight(_ textView: UITextView) {
        let text = textView.text!
        let selectedRange = textView.selectedTextRange!
        
        if let host = URL.coercedFrom(text)?.displayHost,
            let highlightRange = text.allNSRanges(of: host).first {
            let attrTxt = NSMutableAttributedString(string: text, attributes: [
                NSAttributedStringKey.foregroundColor: textView.textColor!.withSecondaryAlpha,
                NSAttributedStringKey.font: textView.font!
                ])
            let highlight = [ NSAttributedStringKey.foregroundColor: textView.textColor! ]
            attrTxt.addAttributes(highlight, range: highlightRange)
            textView.attributedText = attrTxt
        } else {
            setBackground(backgroundView.overlayColor!)
            textView.text = text
        }
        
        textView.selectedTextRange = selectedRange
    }

    func updateSuggestion(for text: String) {
        if shouldShowActions || text == "" {
            if UIPasteboard.general.hasStrings {
                suggestions = [
                    TypeaheadSuggestion(title: "Copy", detail: nil, url: nil),
                    TypeaheadSuggestion(title: "Paste", detail: nil, url: nil),
                    TypeaheadSuggestion(title: "Paste and go", detail: nil, url: nil),
                ]
            } else {
                suggestions = [
                    TypeaheadSuggestion(title: "Copy", detail: nil, url: nil),
                ]
            }
            self.renderSuggestions()
            return
        }

        let suggestionsForText = textView.text
        TypeaheadProvider.shared.suggestions(
            for: textView.text,
            maxCount: maxTypeaheadSuggestions
        ) { newList in
            // If text has changed since return, bail early
            if self.textView.text != suggestionsForText { return }
            self.suggestions = newList
            self.renderSuggestions()
        }
    }

    var shouldShowActions: Bool {
        return browserVC?.editableLocation == textView.text || (browserVC != nil && textView.text == "")
    }

    func renderSuggestions() {
        if view.window == nil {
//            fatalError("Rendering before window")
            return
        }
        suggestionTable.reloadData()
        suggestionTable.layoutIfNeeded()
    }
    
    func calculateTextHeight() -> CGFloat {
        let fixedWidth = textView.bounds.size.width
        textView.textContainerInset = textFieldInsets
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        textView.isScrollEnabled = fullTextSize.height > maxTextFieldHeight
        return max(20, min(fullTextSize.height, maxTextFieldHeight))
    }

    func updateTextViewSize() {
        textHeight = calculateTextHeight()
        textHeightConstraint.constant = textHeight
        textViewContainerHeightConstraint.constant = textHeight
    }
    
    func updateLabel() {
        guard let text = textView.text else { return }
        if let url = URL.coercedFrom(text) {
            locationLabel.text = url.displayHost
            locationLabel.showSearch = false
        } else {
            locationLabel.text = text
            locationLabel.showSearch = true
        }
        locationLabel.showBrokenLock = false
        locationLabel.layoutIfNeeded()
        let shift = calculateHorizontalOffset().shift
        labelCenterConstraint.constant = -shift
    }
    
    func calculateHorizontalOffset() -> SearchTransitionOffsets {
        
        let prefix = textView.text.urlPrefix
        let prefixSize = prefix?.boundingRect(
            with: textView.bounds.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSAttributedStringKey.font: textView.font!],
            context: nil)
        let prefixWidth: CGFloat = prefixSize?.width ?? 0
        
        let hasSearch = locationLabel.showSearch
        let hasLock = locationLabel.showBrokenLock && !hasSearch
        
        let labelWidthScaledUp = locationLabel.bounds.width * transition.fontScaledUp
        let textFieldWidth = textView.bounds.width
        
        let titleToTextDist = (textFieldWidth - labelWidthScaledUp ) / 2
        let roomForLockShift: CGFloat = (hasLock ? lockWidth : 0) + (hasSearch ? searchWidth : 0)
        
        let titleHorizontalShift: CGFloat = titleToTextDist + roomForLockShift - prefixWidth + extraXShift
        
        let anchorPos = prefixWidth + labelWidthScaledUp * 0.5
        
        let anchor = CGPoint(
            x: anchorPos / textFieldWidth,
            y: 0.5
        )
        
        return SearchTransitionOffsets(
            shift: titleHorizontalShift,
            anchor: anchor,
            prefixWidth: prefixWidth
        )
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n", let entry = textView.text {
            navigateToSearchOrSite(entry)
            return false
        }
        return true
    }
    
    func navigateToSearchOrSite(_ entry: String) {
        if let url = URL.coercedFrom(entry) {
            navigateTo(url)
            return
        }
        let url = TypeaheadProvider.shared.serpURLfor(entry)!
        navigateTo(url)
    }

    func navigateTo(_ url: URL) {
        if let browser = self.browserVC {
            browser.navigateTo(url)
            locationLabel.text = browser.displayLocation
            setBackground(.black) // since navigate insta-hides
            animateToSheetHidden()
            return
        }
    }
}

extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = suggestions[indexPath.item]
        
//        textView.text = row.title
//        label.text = row.title
//        label.showSearch = false
//        label.showLock = false
        if let url = row.url {
            textView.text = row.url?.absoluteString
            updateFieldForNewText()
            navigateTo(url)
        } else if row.title == "Copy" {
            UIPasteboard.general.string = browserVC?.editableLocation
            tableView.deselectRow(at: indexPath, animated: true)
            if let cell = tableView.cellForRow(at: indexPath) {
                cell.textLabel?.text = "Copied ✓"
            }
        } else if row.title == "Paste" {
            if let str = UIPasteboard.general.string {
                textView.text = str
                updateFieldForNewText()
            }
            tableView.deselectRow(at: indexPath, animated: true)
        } else if row.title == "Paste and go" {
            if let str = UIPasteboard.general.string {
                textView.text = str
                updateFieldForNewText()
                DispatchQueue.main.async {
                    self.navigateToSearchOrSite(str)
                }
            }
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}

struct SearchTransitionOffsets {
    let shift: CGFloat
    let anchor: CGPoint
    let prefixWidth: CGFloat
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(maxTypeaheadSuggestions, suggestions.count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = tableView.dequeueReusableCell(withIdentifier: typeaheadReuseID, for: indexPath)
        guard let cell = row as? TypeaheadCell else { return row }

        // Configure the cells
        let suggestion = suggestions[indexPath.item]
        let currentText = textView.text ?? ""

        cell.configure(title: suggestion.title, detail: suggestion.detail, highlight: currentText)

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        if indexPath.item > suggestions.count {
//            fatalError("asked for invalid row")
//        }
//        let item = suggestions[indexPath.item]
//        var h: CGFloat = 60.0
//        if let t = item.title, t.count > 60 { h += 20 }
        return 60
    }
}

// MARK: - Gesture

let SPACE_FOR_INDICATOR: CGFloat = 26

extension SearchViewController: UIGestureRecognizerDelegate {
    private func verticalPan(gesture: UIPanGestureRecognizer, isEntrance: Bool = false) {

        var dist = gesture.translation(in: view)
        let vel = gesture.velocity(in: view)

        if isEntrance {
            dist.y += baseSheetHeight - Const.toolbarHeight
        }

        if gesture.state == .began {
            isSwiping = true
//            textView.tintColor = .clear
            textView.resignFirstResponder()
        } else if gesture.state == .changed {
            if dist.y < 0 {
                let elastic = 1 * elasticLimit(-dist.y)
                sheetHeight.constant = baseSheetHeight + elastic
            } else {
                let elastic = elasticLimit(dist.y)
                sheetHeight.constant = max(baseSheetHeight - elastic, minSheetHeight)
            }
        } else if gesture.state == .ended || gesture.state == .cancelled {
            isSwiping = false
            if vel.y > 100 || sheetHeight.constant < 100 {
                transition.velocity = gesture.velocity(in: view)
                animateToSheetHidden()
            } else {
                animateToSheetVisible(at: gesture.velocity(in: view))
            }
        }
    }

    func animateToSheetVisible(at velocity: CGPoint) {
        isTransitioning = true
        
        sheetHeight.constant = baseSheetHeight
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
                self.view.layoutIfNeeded()
//                self.textView.becomeFirstResponder()
        }, completion: { _ in
            self.isTransitioning = false
            self.focusTextView()
        });
    }
    
    @objc func animateToSheetHidden() {
        if isTransitioning || view.superview == nil { return }
        transition.direction = .dismiss
        transition.animateTransition(searchVC: self, browserVC: browserVC!, completion: nil)
    }


    @objc func handleDimissPan(_ gesture: UIPanGestureRecognizer) {
        verticalPan(gesture: gesture, isEntrance: false)
    }

    func handleEntrancePan(_ gesture: UIPanGestureRecognizer) {
        isSwiping = true
        verticalPan(gesture: gesture, isEntrance: true)
    }
}

// MARK: - Actions
extension SearchViewController: PageActionHandler {
    func refresh() {
        browserVC?.webView.reload()
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
        } else if !pageActionView.isBookmarked {
            guard let url = browserVC?.webView.url, let title = browserVC?.webView.title else { return }
            BookmarkProvider.shared.addBookmark(url, title: title) { isBookmarked in
                if isBookmarked { self.pageActionView.isBookmarked = true }
            }
        } else if pageActionView.isBookmarked {
//            BookmarkProvider.shared.add(browser?.webView.url)
            let options = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            options.addAction(UIAlertAction(title: "Edit", style: .default, handler: nil))
            options.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { _ in
                guard let url = self.browserVC?.webView.url else { return }
                BookmarkProvider.shared.removeBookmark(url) { isRemoved in
                    if isRemoved { self.pageActionView.isBookmarked = false }
                }
            }))
            options.addAction(UIAlertAction(title: "Log Out", style: .default, handler: { _ in
                BookmarkProvider.shared.logOut()
                self.pageActionView.isBookmarkEnabled = false
                self.pageActionView.isBookmarked = false
            }))
            options.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            }))
            DispatchQueue.main.async {
                self.present(options, animated: true)
            }
        }
    }

    func share() {
        browserVC?.makeShareSheet { avc in
            self.present(avc, animated: true, completion: nil)
        }
    }

    func copy() {
        let b = browserVC
        b?.copyURL()
        let alert = UIAlertController(title: "Copied", message: nil, preferredStyle: .alert)
        present(alert, animated: true, completion: {
            alert.dismiss(animated: true)
        })
    }
}
