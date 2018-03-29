//
//  ToolbarSearchField.swift
//  browse
//
//  Created by Evan Brooks on 5/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ToolbarSearchField: ToolbarTouchView {
    
    var label = UILabel()
    var lock : UIImageView!
    var magnify : UIImageView!
    var labelHolder : UIView!
    
    var centerConstraint : NSLayoutConstraint!
    
    private var shouldShowLock : Bool = false

    var text : String? {
        get {
            return label.text
        }
        set {
            if newValue == "" {
                label.text = "Where to?"
                progress = 0
            }
            else {
                if label.text != newValue {
                    label.text = newValue
                }
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
            lock.isHidden = !shouldShowLock || isSearch
        }
    }
    
    var isSearch : Bool {
        get {
            return !magnify.isHidden
        }
        set {
            magnify.isHidden = !newValue
            lock.isHidden = !shouldShowLock || isSearch
        }
    }
    
    var isLoading : Bool {
        get {
            return false
        }
        set {
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 180.0, height: Const.shared.buttonHeight)
    }
    
    init(onTap: ToolbarButtonAction? = nil) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: Const.shared.buttonHeight), onTap: onTap)
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)
        
        label.text = "Where to?"
        label.font = Const.shared.thumbTitle
        label.adjustsFontSizeToFitWidth = false
        label.setContentHuggingPriority(UILayoutPriority(rawValue: 0), for: .horizontal)

        labelHolder = UIView(frame: bounds)
        labelHolder.translatesAutoresizingMaskIntoConstraints = false
//        labelHolder.backgroundColor = .cyan
        addSubview(labelHolder)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.spacing = 4.0
        
        stackView.addArrangedSubview(lock)
        stackView.addArrangedSubview(magnify)
        stackView.addArrangedSubview(label)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        labelHolder.addSubview(stackView)
        labelHolder.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        labelHolder.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true

        labelHolder.centerYAnchor.constraint(equalTo: stackView.centerYAnchor).isActive = true
        labelHolder.centerXAnchor.constraint(equalTo: stackView.centerXAnchor).isActive = true

        labelHolder.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        labelHolder.heightAnchor.constraint(equalTo: heightAnchor).isActive = true

        labelHolder.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        stackView.centerXAnchor.constraint(equalTo: labelHolder.centerXAnchor).isActive = true
        
        let maskLayer = CAGradientLayer()
        maskLayer.frame = labelHolder.frame
        maskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        maskLayer.locations = [0, 0.01]
        maskLayer.colors = [UIColor.blue.cgColor, UIColor.blue.withAlphaComponent(0.3).cgColor]
        labelHolder.layer.mask = maskLayer
        
        isSecure = false
        isSearch = false
        isLoading = false
    }
    
    var progress : CGFloat {
        get {
            return label.alpha
        }
        set {
            let pct = newValue

            if let grad = labelHolder.layer.mask as? CAGradientLayer {
                let val = pct as NSNumber
                let val2 = (pct + 0.005) as NSNumber
                UIView.animate(withDuration: 0.2) {
                    grad.locations = [val, val2]
                }
                grad.frame = labelHolder.bounds // TODO set this in a normal place
            }

        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = tintColor
    }

}
