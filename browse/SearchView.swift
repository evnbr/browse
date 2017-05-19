//
//  SearchView.swift
//  browse
//
//  Created by Evan Brooks on 5/18/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

class SearchView: UIView, UITextViewDelegate {
    
    var senderVC : SiteViewController!
    var textView : UITextView!
    
    init() {
        super.init(frame: CGRect(
            x: 0,
            y: 300,
            width: UIScreen.main.bounds.width,
            height: 600
        ))
        
        backgroundColor = UIColor.white
        
        textView = UITextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 100)
        textView.inputAccessoryView = self
        
        textView.backgroundColor = UIColor.black.withAlphaComponent(0.04)
        textView.font = UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 17)
        textView.text = "Test"
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.delegate = self
        textView.isScrollEnabled = false
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(textView)

        self.autoresizingMask = UIViewAutoresizing.flexibleHeight

        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[textView]|", options: [], metrics: nil, views: ["textView": self.textView]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[textView]|", options: [], metrics: nil, views: ["textView": self.textView]))

        
        updateSize()
        
//        let cancel = UIButton(type: .system)
//        cancel.setTitle("Cancel", for: .normal)
//        cancel.addTarget(self, action: #selector(hide), for: .primaryActionTriggered)
//        cancel.frame = CGRect(x: 12, y: 12, width: 80, height: 80)
//        cancel.sizeToFit()
//        self.addSubview(cancel)
    }
    
    func updateSize() {
        let fixedWidth = textView.frame.size.width
        textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        var newFrame = textView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
        textView.frame = newFrame;
        
        textView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12)
        textView.contentInset = .zero
        
        var frame = self.frame
        frame.size.height = textView.frame.size.height + 12
        self.frame = frame
//        textView.reloadInputViews()
        
        textView.invalidateIntrinsicContentSize()
        //        textView.scrollRangeToVisible(NSMakeRange(0, 0))
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
        textView.transform = CGAffineTransform.identity.translatedBy(x: 40, y: 0)

        UIView.animate(withDuration: 0.3, animations: {
            textView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 0)
        })
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 0)

        UIView.animate(withDuration: 0.3, animations: {
            textView.transform = CGAffineTransform.identity.translatedBy(x: 40, y: 0)
        })
    }

    func textViewDidChange(_ textView: UITextView) {
        updateSize()
    }
    
    func hide() {
        senderVC.hideSearch()
    }
    
    
    
    func updateAppearance() {
        textView.text = senderVC.webView.url?.absoluteString
        self.backgroundColor = senderVC.colorAtBottom
        self.tintColor = senderVC.toolbar.tintColor
        textView.textColor = senderVC.toolbar.tintColor
        
        textView.keyboardAppearance = senderVC.colorAtBottom.isLight() ? .dark : .light
        
        updateSize()
    }
    
    
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            hide()
            senderVC.navigateToText(textView.text!)
            return false
        }
        return true
    }
    
}
