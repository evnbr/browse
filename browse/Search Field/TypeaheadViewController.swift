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

class TypeaheadViewController: UIViewController {

    var contentView: UIView!
    var scrim: UIView!
    var textView: SearchTextView!
    var cancel: ToolbarTextButton!
    var suggestionTable: UITableView!

    var displaySearchTransition = TypeaheadAnimationController()
    
    var kbHeightConstraint : NSLayoutConstraint!
    var suggestHeightConstraint : NSLayoutConstraint!
    var textHeight : NSLayoutConstraint!
    var collapsedTextHeight : NSLayoutConstraint!

    var suggestionHeight : CGFloat = 200
    var keyboardHeight : CGFloat = 250
    
    var suggestions : [String] = [
        "Share",
        "Copy",
        "Refresh",
    ]
    
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
        
        view.backgroundColor = .clear
        
        scrim = UIView(frame: view.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        scrim.addGestureRecognizer(tap)
        
        view.addSubview(scrim)
        
        contentView = UIView(frame: view.bounds)
        contentView.layer.cornerRadius = Const.shared.cardRadius
        contentView.backgroundColor = .white
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.tintColor = .darkText
        contentView.clipsToBounds = true
        view.addSubview(contentView)
        
        contentView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        suggestionTable = UITableView(frame:self.view.frame)
        suggestionTable.rowHeight = 48.0
        suggestionTable.register(UITableViewCell.self, forCellReuseIdentifier: typeaheadReuseID)
        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.dataSource = self
        suggestionTable.delegate = self
        suggestionTable.isScrollEnabled = false
        suggestionTable.separatorStyle = .none
        contentView.addSubview(suggestionTable)

        textView = SearchTextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        textView.placeholder = "Where to?"
        
        textView.font = UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 17)
        textView.text = ""
        
        textView.delegate = self
        textView.isScrollEnabled = true
        
        textView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        textView.layer.cornerRadius = SEARCH_RADIUS
        textView.textColor = .darkText
        textView.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        
        textView.keyboardAppearance = .light
        textView.enablesReturnKeyAutomatically = true
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.autocorrectionType = .no
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        
        cancel = ToolbarTextButton(title: "Cancel", withIcon: nil, onTap: dismissSelf)
        cancel.size = .medium
        cancel.sizeToFit()
        cancel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancel)
        
        cancel.bottomAnchor.constraint(equalTo: textView.bottomAnchor).isActive = true
        cancel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: 0).isActive = true
        cancel.widthAnchor.constraint(equalToConstant: cancel.bounds.width).isActive = true
        cancel.heightAnchor.constraint(equalToConstant: cancel.bounds.height).isActive = true

        textView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 12).isActive = true
        textView.rightAnchor.constraint(equalTo: cancel.leftAnchor, constant: 0).isActive = true
        textHeight = textView.heightAnchor.constraint(equalToConstant: 12)
        textHeight.isActive = true
        
        collapsedTextHeight = textView.heightAnchor.constraint(equalToConstant: 12)
        collapsedTextHeight.isActive = false
        
        
        suggestionTable.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        suggestionTable.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        suggestionTable.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        suggestionTable.bottomAnchor.constraint(equalTo: textView.topAnchor, constant: -12).isActive = true
        suggestHeightConstraint = suggestionTable.heightAnchor.constraint(equalToConstant: suggestionHeight)
        suggestHeightConstraint.isActive = true
        
        kbHeightConstraint = textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        kbHeightConstraint.isActive = true

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
        
        setBackground(.white)
        updateTextViewSize()
        view.layoutIfNeeded()
    }
    
    func setBackground(_ newColor: UIColor) {
        guard isViewLoaded else { return }
        let darkContent = !newColor.isLight
        contentView.backgroundColor = newColor
        view.tintColor = darkContent ? .darkText : .white
        contentView.tintColor = view.tintColor
        textView.textColor = view.tintColor
        textView.backgroundColor = darkContent ? UIColor.black.withAlphaComponent(0.1) : UIColor.white.withAlphaComponent(0.3)
        textView.placeholderColor = darkContent ? UIColor.black.withAlphaComponent(0.4) : UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = darkContent ? .light : .dark
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let browser = self.presentingViewController as? BrowserViewController {
            textView.text = browser.editableLocation
            updateTextViewSize()
            updateSuggestion()
        }
        
        textView.becomeFirstResponder()
        textView.selectAll(nil) // if not nil, will show actions
    }
    
    @objc
    func dismissSelf() {
        self.dismiss(animated: true)
        textView.resignFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame: NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        keyboardHeight = keyboardRectangle.height
//        kbHeightConstraint.constant = -keyboardHeight
        // update
    }
}
    
extension TypeaheadViewController : UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateTextViewSize()
        updateSuggestion()
    }
    
    func updateSuggestion() {
        Typeahead.shared.suggestions(for: textView.text, maxCount: 4) { arr in
            self.suggestions = arr.reversed()
            self.suggestHeightConstraint.constant = self.suggestionTable.rowHeight * CGFloat(self.suggestions.count)
            self.suggestionTable.reloadData()
            self.suggestionTable.layoutIfNeeded()
        }
    }
    
    func updateTextViewSize() {
        let fixedWidth = textView.frame.size.width
        textView.textContainerInset = UIEdgeInsetsMake(10, 12, 10, 12)
        
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        var newFrame = textView.frame
        let newHeight: CGFloat = max(20, min(fullTextSize.height, SEARCHVIEW_MAX_H))  // 80.0
        
        newFrame.size = CGSize(width: max(fullTextSize.width, fixedWidth), height: newHeight)
        //        textView.frame = newFrame;
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        textHeight.constant = newHeight
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            navigateTo(textView.text)
            return false
        }
        return true
    }
    
    func navigateTo(_ text: String) {
        if let browser = self.presentingViewController as? BrowserViewController {
            browser.navigateToText(text)
            dismissSelf()
            return
        }
        if let nav = self.presentingViewController as? UINavigationController {
            if let switcher = nav.topViewController as? TabSwitcherViewController {
                self.dismiss(animated: false, completion: {
                    switcher.addTab(startingFrom: text)
                })
                textView.resignFirstResponder()
                return
            }
        }
    }
}

extension TypeaheadViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let text = suggestions[indexPath.item]
        navigateTo(text)
    }
}

extension TypeaheadViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(MAX_ROWS, suggestions.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: typeaheadReuseID, for: indexPath)
        // Configure the cells
        cell.textLabel?.text = suggestions[indexPath.item]
        return cell
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

