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
    var lock: UIImageView!
    var magnify: UIImageView!
    var labelHolder : UIView!
    let maskLayer = CAGradientLayer()
    var stopButton: ToolbarIconButton!
    
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
            else if label.text != newValue {
                label.text = newValue
            }
//            label.sizeToFit()
            var size = label.sizeThatFits(labelHolder.bounds.size)
            size.width = min(size.width, bounds.width - lock.bounds.width) // room for decorations
            label.bounds.size = size
            renderProgress(animated: false)
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
            return labelHolder.layer.mask == nil
        }
        set {
            labelHolder.layer.mask = newValue ? maskLayer : nil
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 180.0, height: Const.shared.buttonHeight)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        renderProgress(animated: false)
    }
    
    init(onTap: ToolbarButtonAction? = nil) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: Const.shared.buttonHeight), onTap: onTap)
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)
        
        label.text = "Where to?"
        label.font = Const.shared.thumbTitleFont
        label.adjustsFontSizeToFitWidth = false
        label.setContentHuggingPriority(UILayoutPriority(rawValue: 0), for: .horizontal)

        labelHolder = UIView(frame: bounds)
        labelHolder.translatesAutoresizingMaskIntoConstraints = false
//        labelHolder.backgroundColor = .cyan
        addSubview(labelHolder)
        
        stopButton = ToolbarIconButton(icon: UIImage(named: "stop"))
        addSubview(stopButton)
        stopButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        stopButton.frame.origin.x = frame.width - stopButton.frame.width

        let labelContent = UIStackView()
        labelContent.axis = .horizontal
        labelContent.distribution = .fill
        labelContent.alignment = .center
        labelContent.spacing = 4.0
        
        labelContent.addArrangedSubview(lock)
        labelContent.addArrangedSubview(magnify)
        labelContent.addArrangedSubview(label)
        labelContent.translatesAutoresizingMaskIntoConstraints = false
        
        labelHolder.addSubview(labelContent, constraints: [
            labelHolder.centerYAnchor.constraint(equalTo: centerYAnchor),
            labelHolder.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelHolder.centerYAnchor.constraint(equalTo: labelContent.centerYAnchor),
            labelHolder.centerXAnchor.constraint(equalTo: labelContent.centerXAnchor),
            labelHolder.widthAnchor.constraint(equalTo: labelContent.widthAnchor),
            labelHolder.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            labelHolder.heightAnchor.constraint(equalTo: heightAnchor),
            labelHolder.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelHolder.centerXAnchor.constraint(equalTo: labelContent.centerXAnchor)
        ])
        
        maskLayer.frame = labelHolder.frame
        maskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        maskLayer.locations = [0, 0.005]
        maskLayer.colors = [UIColor.blue.cgColor, UIColor.blue.withAlphaComponent(0.3).cgColor]
        
        isSecure = false
        isSearch = false
        isLoading = false
    }
    
    var _progress : CGFloat = 0
    var progress : CGFloat {
        get {
            return _progress
        }
        set {
            let oldValue = _progress
            _progress = newValue
            renderProgress(animated: oldValue < newValue)
        }
    }
    
    func renderProgress(animated: Bool) {
        maskLayer.frame = labelHolder.bounds
        
        let val = _progress as NSNumber
        let val2 = (_progress + 0.005) as NSNumber
        
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.maskLayer.locations = [val, val2]
            }
        }
        else {
            CATransaction.begin()
            CATransaction.disableActions()
            maskLayer.locations = [val, val2]
            CATransaction.commit()
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
