//
//  LocationBar.swift
//  browse
//
//  Created by Evan Brooks on 5/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

enum LocationBarAlignment {
    case left
    case centered
}

class LocationBar: ToolbarTouchView {
    
    var label = UILabel()
    var spinner : UIActivityIndicatorView!
    var lock : UIImageView!
    var magnify : UIImageView!
    
    var alignment : LocationBarAlignment = .centered
    var leftConstraint : NSLayoutConstraint!
    var centerConstraint : NSLayoutConstraint!
    
    
    private var shouldShowLock : Bool = false
    private var shouldShowSpinner : Bool = false

    var text : String? {
        get {
            return label.text
        }
        set {
            if newValue == "" {
                label.text = "Where to?"
                label.alpha = 0.6
                magnify.alpha = 0.6
            }
            else {
                label.text = newValue
                label.alpha = 1
                magnify.alpha = 1
            }
            label.sizeToFit()
        }
    }
    
    var isSecure : Bool {
        get {
            return shouldShowLock
        }
        set {
            shouldShowLock = newValue
            lock.isHidden = !shouldShowLock || isSearch || shouldShowSpinner
        }
    }
    
    var isSearch : Bool {
        get {
            return !magnify.isHidden
        }
        set {
            magnify.isHidden = !newValue
            lock.isHidden = !shouldShowLock || isSearch || shouldShowSpinner
        }
    }
    
    var isLoading : Bool {
        get {
            return shouldShowSpinner
        }
        set {
            shouldShowSpinner = newValue
            spinner.isHidden = !shouldShowSpinner
//
//            lock.isHidden = !shouldShowLock || isSearch || shouldShowSpinner
//
            if newValue { spinner.startAnimating() }
            else        { spinner.stopAnimating()  }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 180.0, height: TOOLBAR_H)
    }
    
    init(onTap: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: TOOLBAR_H), onTap: onTap)
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)
        
        label.text = "Where to?"
        label.font = UIFont.systemFont(ofSize: 13.0)
        label.setContentHuggingPriority(UILayoutPriority(rawValue: 0), for: .horizontal)
//        label.sizeToFit()
        
        spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
//        spinner.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        spinner.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // https://stackoverflow.com/questions/30728062/add-views-in-uistackview-programmatically
        let stackView   = UIStackView()
        stackView.axis  = .horizontal
        stackView.distribution  = .fill
        stackView.alignment = .center
        stackView.spacing   = 6.0
        
        stackView.addArrangedSubview(spinner)
        stackView.addArrangedSubview(lock)
        stackView.addArrangedSubview(magnify)
        stackView.addArrangedSubview(label)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        centerConstraint = stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        leftConstraint = stackView.leftAnchor.constraint(equalTo: self.leftAnchor)
        centerConstraint.isActive = true
        leftConstraint.isActive = false
        
        stackView.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor).isActive = true
        
        isSecure = false
        isSearch = false
        isLoading = false
        
//        layer.borderColor = UIColor.red.cgColor
//        layer.borderWidth = 0.5
        
    }
    
    func setAlignment(_ newAlignment: LocationBarAlignment) {
        if newAlignment != alignment {
            alignment = newAlignment
            if newAlignment == .centered {
                centerConstraint.isActive = true
                leftConstraint.isActive = false
            }
            else if newAlignment == .left {
                centerConstraint.isActive = false
                leftConstraint.isActive = true
            }
            
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = tintColor
        spinner.color = tintColor
    }

}
