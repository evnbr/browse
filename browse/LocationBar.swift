//
//  LocationBar.swift
//  browse
//
//  Created by Evan Brooks on 5/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class LocationBar: ToolbarTouchView {
    
    var label = UILabel()
    var lock : UIImageView!
    var magnify : UIImageView!
    
    private var shouldShowLock : Bool = false

    var text : String? {
        get {
            return label.text
        }
        set {
            label.text = newValue
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
    
    init(onTap: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: 40), onTap: onTap)
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)

        label.text = "Where to?"
        label.font = UIFont.systemFont(ofSize: 14.0)
        label.sizeToFit()
        
        
        // https://stackoverflow.com/questions/30728062/add-views-in-uistackview-programmatically
        let stackView   = UIStackView()
        stackView.axis  = .horizontal
        stackView.distribution  = .equalSpacing
        stackView.alignment = .center
        stackView.spacing   = 6.0
        
        stackView.addArrangedSubview(lock)
        stackView.addArrangedSubview(magnify)
        stackView.addArrangedSubview(label)
        stackView.translatesAutoresizingMaskIntoConstraints = false;
        
        addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        isSecure = false
        isSearch = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = tintColor
    }

}
