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
    var lock : UIImageView!
    var magnify : UIImageView!
    
    var alignment : LocationBarAlignment = .centered
    var leftConstraint : NSLayoutConstraint!
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
//                label.alpha = 0.6
//                magnify.alpha = 0.6
            }
            else {
                label.text = newValue
//                label.alpha = 1
//                magnify.alpha = 1
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
    
    init(onTap: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: Const.shared.buttonHeight), onTap: onTap)
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)
        
        label.text = "Where to?"
//        label.font = UIFont.systemFont(ofSize: 16.0)
        label.font = Const.shared.thumbTitle
        label.adjustsFontSizeToFitWidth = true
        label.setContentHuggingPriority(UILayoutPriority(rawValue: 0), for: .horizontal)

        let stackView   = UIStackView()
        stackView.axis  = .horizontal
        stackView.distribution  = .fill
        stackView.alignment = .center
        stackView.spacing   = 4.0
        
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
        
        let maskLayer = CAGradientLayer()
        maskLayer.frame = frame
        maskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        maskLayer.locations = [0, 0.01]
        maskLayer.colors = [UIColor.blue.cgColor, UIColor.blue.withAlphaComponent(0.3).cgColor]
        layer.mask = maskLayer
        
        
        isSecure = false
        isSearch = false
        isLoading = false
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
    
    var progress : CGFloat {
        get {
            return label.alpha
        }
        set {
            let pctRange = (label.bounds.width + 32) / self.bounds.width
            let adjustedPct = ((1 - pctRange) / 2) + newValue * pctRange

            UIView.animate(withDuration: 0.2) {
//                self.layer.mask?.frame.origin.x = -200 + 200 * newValue
                if let grad = self.layer.mask as? CAGradientLayer {
                    
                    let val = adjustedPct as NSNumber
                    let val2 = (adjustedPct + 0.01) as NSNumber
                    grad.locations = [val, val2]
                    grad.frame = self.bounds // TODO set this in a normal place
                }
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
