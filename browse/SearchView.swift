//
//  SearchView.swift
//  browse
//
//  Created by Evan Brooks on 5/18/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

let SEARCHVIEW_MAX_H : CGFloat = 160.0

class SearchView: UIView, UITextViewDelegate {
    
    var BrowserViewController : BrowserViewController!
    var textView : SearchTextView!
    var cancel   : ToolbarTextButton!
    
    var fullWidthConstraint : NSLayoutConstraint!
    var roomForCancelConstraint : NSLayoutConstraint!
    
    var isEnabled : Bool {
        get {
            return self.isUserInteractionEnabled
        }
        set {
            self.isUserInteractionEnabled = newValue
        }
    }
    
    init(for vc: BrowserViewController) {
        super.init(frame: CGRect(
            x: 0,
            y: 300,
            width: UIScreen.main.bounds.width,
            height: 600
        ))
        
        BrowserViewController = vc
        
        self.isEnabled = false
        
        textView = SearchTextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        textView.placeholder = "Where to?"
        
        textView.font = UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 17)
        textView.text = ""
        
        backgroundColor =  .clear
        tintColor = .white
        
        textView.delegate = self
        textView.isScrollEnabled = true
        
        textView.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        textView.layer.cornerRadius = CORNER_RADIUS
        textView.textColor = .white
        textView.alpha = 0
        textView.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        
        textView.keyboardAppearance = .dark
        textView.enablesReturnKeyAutomatically = true
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.autocorrectionType = .no

        textView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(textView)
        
        cancel = ToolbarTextButton(title: "Cancel", withIcon: nil, onTap: self.BrowserViewController.hideSearch)
        cancel.size = .medium
        cancel.sizeToFit()
        
        let cancelOrigin = CGPoint(
            x: self.frame.size.width - cancel.frame.size.width,
            y: self.frame.size.height - cancel.frame.size.height - 4
        )
        cancel.frame = CGRect(origin: cancelOrigin, size: cancel.frame.size)
        cancel.alpha = 0
        self.addSubview(cancel)
        cancel.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        
        
        self.autoresizingMask = UIViewAutoresizing.flexibleHeight
        translatesAutoresizingMaskIntoConstraints = false
        
        textView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 8).isActive = true
        textView.topAnchor.constraint(equalTo: self.topAnchor, constant: 12).isActive = true
        
        fullWidthConstraint = textView.widthAnchor.constraint(equalTo: self.widthAnchor, constant: -16)
        roomForCancelConstraint = textView.widthAnchor.constraint(equalTo: self.widthAnchor, constant: -cancel.frame.width - 8)
        fullWidthConstraint.isActive = true
        roomForCancelConstraint.isActive = false
        
        
        self.heightAnchor.constraint(equalTo: textView.heightAnchor, constant: 20).isActive = true
        self.heightAnchor.constraint(lessThanOrEqualToConstant: SEARCHVIEW_MAX_H).isActive = true
        
        
        
        // TODO this doesn't seem to work
        updateSize()
    }
    
    func updateSize() {
        let fixedWidth = textView.frame.size.width

//        textView.textContainerInset = UIEdgeInsetsMake(13, 14, 13, leftMargin)
        textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8)
        
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        var newFrame = textView.frame
        
        let newHeight: CGFloat = min(fullTextSize.height, SEARCHVIEW_MAX_H)  // 80.0
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        
        newFrame.size = CGSize(width: max(fullTextSize.width, fixedWidth), height: newHeight)
        textView.frame = newFrame;

        var frame = self.frame
        frame.size.height = newFrame.size.height + 20
        self.frame = frame
        
//        textView.invalidateIntrinsicContentSize()
        self.invalidateIntrinsicContentSize()
        
    }
    
    override public var intrinsicContentSize: CGSize {
        get {
            return frame.size
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.isEnabled = true
        
        fullWidthConstraint.isActive = false
        roomForCancelConstraint.isActive = true
        
        self.updateSize()
        
        textView.alpha = 0
        cancel.alpha = 0
        cancel.transform = CGAffineTransform(translationX: 30, y: 0)

        UIView.animate(withDuration: 0.3, animations: {
            textView.alpha = 1
            
            self.cancel.transform = .identity
            self.cancel.alpha = 1
        }, completion: { completed in
            textView.selectAll(nil) // if not nil, will show actions
        })
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.alpha = 1
        cancel.transform = .identity

//        self.hide()
        // this is just a bad idea
        
        
        roomForCancelConstraint.isActive = false
        fullWidthConstraint.isActive = true
        
        UIView.animate(withDuration: 0.3, animations: {
            textView.alpha = 0
            self.cancel.transform = CGAffineTransform(translationX: 30, y: 0)
            self.cancel.alpha = 0
            
        }, completion: { completed in
            
            self.isEnabled = false
            textView.selectedTextRange = nil
        })
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updateSize()
        BrowserViewController.searchSizeDidChange()
    }
    
    func prepareToShow() {
        
    }
    
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            BrowserViewController.hideSearch()
            BrowserViewController.navigateToText(textView.text!)
            return false
        }
        return true
    }
    
}
