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
    var cancel   : UIButton!
    
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
        textView.placeholder = "Where to?"
        
        textView.backgroundColor = UIColor.clear
        textView.font = UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 17)
        textView.text = "Test"
        
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.inputAccessoryView = self
        textView.autocorrectionType = .no

        textView.delegate = self
        textView.isScrollEnabled = false
        textView.layer.cornerRadius = 5.0
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(textView)

        cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(hide), for: .primaryActionTriggered)
        cancel.sizeToFit()
        let cancelOrigin = CGPoint(
            x: self.frame.size.width - cancel.frame.size.width - 12,
            y: self.frame.size.height - cancel.frame.size.height - 8
        )
        cancel.frame = CGRect(origin: cancelOrigin, size: cancel.frame.size)
        self.addSubview(cancel)
        cancel.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        
        self.autoresizingMask = UIViewAutoresizing.flexibleHeight
        let margin = Int(cancel.frame.size.width) + 28
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-8-[text]-\(margin)-|", options: [], metrics: nil, views: ["text": self.textView]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[text]-8-|", options: [], metrics: nil, views: ["text": self.textView]))

        
        updateSize()
        
    }
    
    func updateSize() {
        let fixedWidth = textView.frame.size.width
        textView.textContainerInset = UIEdgeInsetsMake(5, 6, 5, 6)
        textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        var newFrame = textView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
        textView.frame = newFrame;
        
        textView.contentInset = .zero
        
        var frame = self.frame
        frame.size.height = textView.frame.size.height + 16
        self.frame = frame
        
        textView.invalidateIntrinsicContentSize()
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
        textView.transform = CGAffineTransform(translationX: 20, y: 0)
        textView.alpha = 0
        cancel.transform = CGAffineTransform(translationX: 60, y: 0)

        UIView.animate(withDuration: 0.3, animations: {
            textView.transform = .identity
            textView.alpha = 1
            self.cancel.transform = .identity
        })
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.transform = .identity
        textView.alpha = 1
        cancel.transform = .identity

        UIView.animate(withDuration: 0.3, animations: {
            textView.transform = CGAffineTransform(translationX: 20, y: 0)
            textView.alpha = 0
            self.cancel.transform = CGAffineTransform(translationX: 60, y: 0)
        })
    }

    func textViewDidChange(_ textView: UITextView) {
        updateSize()
    }
    
    func hide() {
        senderVC.hideSearch()
    }
    
    
    
    func prepareToShow() {
        textView.text = senderVC.editableURL
        
        self.backgroundColor = senderVC.colorAtBottom
        self.tintColor = senderVC.toolbar.tintColor
        textView.textColor = senderVC.toolbar.tintColor
        
        textView.keyboardAppearance = senderVC.colorAtBottom.isLight ? .dark : .light
        textView.placeholderColor = senderVC.colorAtBottom.isLight
            ? UIColor.white.withAlphaComponent(0.4)
            : UIColor.black.withAlphaComponent(0.2)

//        textView.backgroundColor = senderVC.colorAtBottom.isLight()
//            ? UIColor.white.withAlphaComponent(0.1)
//            : UIColor.black.withAlphaComponent(0.08)

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
