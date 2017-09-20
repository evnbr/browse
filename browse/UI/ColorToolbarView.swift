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
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
//        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
