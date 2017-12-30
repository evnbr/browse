//
//  ColorToolbarView.swift
//  browse
//
//  Created by Evan Brooks on 6/13/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ColorToolbarView: GradientColorChangeView {
    let stackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        tintColor = .white
        clipsToBounds = true
        
        autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
//        translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis  = .horizontal
        stackView.distribution  = .fill
        stackView.alignment = .top
        stackView.spacing   = 0.0
        
        stackView.translatesAutoresizingMaskIntoConstraints = false;
        
        addSubview(stackView)
        
        let toolbarInset : CGFloat = 8.0
//        let roomForIndicator : CGFloat = Const.shared.toolbarHeight - Const.shared.buttonHeight
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8.0).isActive = true
//        stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -roomForIndicator).isActive = true
        stackView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: toolbarInset).isActive = true
        stackView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -toolbarInset).isActive = true
    }
        
    var items : [ UIView ] {
        get {
            return stackView.subviews
        }
        set {
            stackView.subviews.forEach { $0.removeFromSuperview() }
            for item in newValue {
                stackView.addArrangedSubview(item)
            }
        }
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        subviews.forEach { (v) in
            v.tintColor = tintColor
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
