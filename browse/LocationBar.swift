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
    var spinner : UIActivityIndicatorView!
    var lock : UIImageView!
    var magnify : UIImageView!
    
    private var shouldShowLock : Bool = false
    private var shouldShowSpinner : Bool = false

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
            
            lock.isHidden = !shouldShowLock || isSearch || shouldShowSpinner

            if newValue {
                spinner.startAnimating()
            }
            else {
                spinner.stopAnimating()
            }
        }
    }

    
    init(onTap: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 180, height: 40), onTap: onTap)
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)

        label.text = "Where to?"
        label.font = UIFont.systemFont(ofSize: 13.0)
        label.sizeToFit()
        
        spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
//        spinner.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        spinner.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // https://stackoverflow.com/questions/30728062/add-views-in-uistackview-programmatically
        let stackView   = UIStackView()
        stackView.axis  = .horizontal
        stackView.distribution  = .equalSpacing
        stackView.alignment = .center
        stackView.spacing   = 6.0
        
        stackView.addArrangedSubview(spinner)
        stackView.addArrangedSubview(lock)
        stackView.addArrangedSubview(magnify)
        stackView.addArrangedSubview(label)
        stackView.translatesAutoresizingMaskIntoConstraints = false;
        
        addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        isSecure = false
        isSearch = false
        isLoading = false
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
