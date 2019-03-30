//
//  ToolbarSearchField.swift
//  browse
//
//  Created by Evan Brooks on 5/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ToolbarSearchField: ToolbarTouchView {
    
    var labelHolder : UIView!
    let maskLayer = CAGradientLayer()
    var stopButton: ToolbarIconButton!
    
    var locationLabel = LocationLabel()
    
    var text : String? {
        get { return locationLabel.text }
        set {
            locationLabel.text = newValue
            renderProgress(animated: false)
        }
    }
    
    var isSecure : Bool {
        get { return locationLabel.showLock }
        set { locationLabel.showLock = newValue }
    }
    
    var isSearch : Bool {
        get { return locationLabel.showSearch }
        set { locationLabel.showSearch = newValue }
    }
    
    var isLoading : Bool {
        get {
            return labelHolder.layer.mask == nil
        }
        set {
//            labelHolder.layer.mask = newValue ? maskLayer : nil
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 180.0, height: BUTTON_HEIGHT)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        renderProgress(animated: false)
    }
    
    init(onTap: ToolbarButtonAction? = nil) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: BUTTON_HEIGHT), onTap: onTap)
        baseColor = .clear
        

        labelHolder = UIView(frame: bounds)
        labelHolder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelHolder)
        
        stopButton = ToolbarIconButton(icon: UIImage(named: "stop"))
        addSubview(stopButton)
        stopButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        stopButton.frame.origin.x = frame.width - stopButton.frame.width

        
        labelHolder.addSubview(locationLabel, constraints: [
            labelHolder.centerYAnchor.constraint(equalTo: centerYAnchor),
            labelHolder.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelHolder.centerYAnchor.constraint(equalTo: locationLabel.centerYAnchor),
            labelHolder.centerXAnchor.constraint(equalTo: locationLabel.centerXAnchor),
            labelHolder.widthAnchor.constraint(equalTo: locationLabel.widthAnchor, constant: 30),
            labelHolder.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            labelHolder.heightAnchor.constraint(equalTo: heightAnchor),
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
        locationLabel.tintColor = tintColor
//        baseColor = tintColor.isLight ? .darkField : .lightField
    }
}
