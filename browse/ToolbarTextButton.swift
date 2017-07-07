//
//  ToolbarTextButton.swift
//  browse
//
//  Created by Evan Brooks on 7/2/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ToolbarTextButton: ToolbarTouchView {
    
    let label = UILabel()
    let stackView = UIStackView()

    var icon : UIImageView!
    
    var text : String? {
        get {
            return label.text
        }
        set {
            label.text = newValue
            label.sizeToFit()
        }
    }
    
    var showIcon : Bool {
        get {
            return !icon.isHidden
        }
        set {
            icon.isHidden = !newValue
        }
    }
    
    init(title: String, withIcon image: UIImage?, onTap: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: TOOLBAR_H), onTap: onTap)
        
        
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13.0)
        label.sizeToFit()
        
        // https://stackoverflow.com/questions/30728062/add-views-in-uistackview-programmatically
        stackView.axis  = .horizontal
        stackView.distribution  = .equalSpacing
        stackView.alignment = .center
        stackView.spacing   = 6.0
        
        if image != nil {
            let template = image!.withRenderingMode(.alwaysTemplate)
            icon = UIImageView(image: template)
            stackView.addArrangedSubview(icon)
            showIcon = true
        }
        else {
            showIcon = false
        }
        
        stackView.addArrangedSubview(label)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false;
        
        addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = tintColor
    }
    
}
