//
//  BrowserToolbarView.swift
//  browse
//
//  Created by Evan Brooks on 7/12/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class BrowserToolbarView: ColorToolbarView {
    
    private let progressView: UIProgressView = UIProgressView(progressViewStyle: .default)
    var heightConstraint: NSLayoutConstraint!
    var backButton: ToolbarIconButton!
    var stopButton: ToolbarIconButton!
    var tabButton: ToolbarIconButton!
    var searchField: ToolbarSearchField!

    var text: String? {
        get { return searchField.text }
        set { searchField.text = newValue }
    }
    var progress: CGFloat {
        get { return searchField.progress }
        set { searchField.progress = newValue }
    }
    
    var contentsAlpha: CGFloat {
        get { return searchField.alpha }
        set {
            searchField.alpha = newValue
            backButton.alpha = newValue
            tabButton.alpha = newValue
        }
    }
    
    var isSecure: Bool {
        get { return searchField.isSecure }
        set { searchField.isSecure = newValue }
    }
    
    var isSearch: Bool {
        get { return searchField.isSearch }
        set { searchField.isSearch = newValue }
    }
    
    var isLoading: Bool {
        get { return searchField.isLoading }
        set { searchField.isLoading = newValue }
    }

    
    var progressOLD : Float {
        get {
            return progressView.progress
        }
        set {
            progressView.alpha = 1.0
            let isIncreasing = progressView.progress < newValue
            
            progressView.setProgress(0.1 + newValue * 0.8, animated: isIncreasing)
            if (newValue >= 1.0) {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.progress = 1.0
                    self.progressView.alpha = 0
                }, completion: { (finished) in
                    self.progressView.setProgress(0.0, animated: false)
                })
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: frame.height - 2),
            size:CGSize(width: UIScreen.main.bounds.size.width, height: 2)
        )
        progressView.trackTintColor = UIColor.clear
        progressView.progressTintColor = UIColor.darkText
        progressView.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
//        addSubview(progressView)
        
        let blur = PlainBlurView(frame: bounds)
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)
        sendSubview(toBack: blur)
        
        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: Const.toolbarHeight)
        heightConstraint.isActive = true
        
        searchField = ToolbarSearchField()
        backButton = ToolbarIconButton(icon: UIImage(named: "back"))
        tabButton = ToolbarIconButton(icon: UIImage(named: "tab"))
        stopButton = ToolbarIconButton(icon: UIImage(named: "stop"))
        
        searchField.addSubview(stopButton)
        stopButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        stopButton.frame.origin.x = searchField.frame.width - stopButton.frame.width
        
        items = [backButton, searchField, tabButton]
    }
        
    override func tintColorDidChange() {
        super.tintColorDidChange()
        subviews.forEach { (v) in
            v.tintColor = tintColor
        }
        progressView.progressTintColor = tintColor
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
