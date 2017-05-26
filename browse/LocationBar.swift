//
//  LocationBar.swift
//  browse
//
//  Created by Evan Brooks on 5/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class LocationBar: UIControl {
    
    var label = UILabel()
    var lock : UIImageView!
    var magnify : UIImageView!
    var action: () -> Void
    
    private var shouldShowLock : Bool = false

    var text : String? {
        get {
            return label.text
        }
        set {
            label.text = newValue
            label.sizeToFit()
            
//            var newFrame = label.frame
//            newFrame.origin.x = (isSearch || isSecure) ? 24 : 0
//            label.frame = newFrame
        
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
    
//    override var isSelected: Bool {
//        get {
//            return label.backgroundColor == UIColor.clear
//        }
//        set {
//            label.backgroundColor = newValue ? UIColor.blue : UIColor.clear
//        }
//    }
    
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
        action = onTap
        super.init(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        backgroundColor = .clear
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)

        label.text = "Where to?"
        label.font = UIFont.systemFont(ofSize: 15.0)
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

        
        let tap = UITapGestureRecognizer(target: self, action: #selector(doAction))
        tap.numberOfTapsRequired = 1
        tap.isEnabled = true
        tap.cancelsTouchesInView = false
        
        addGestureRecognizer(tap)
        

        isSecure = false
        isSecure = false
//        sizeToFit()
    }
    
    func doAction() {
        action()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func tintColorDidChange() {
        label.textColor = tintColor
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            backgroundColor = UIColor.black.withAlphaComponent(0.08)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            // do something with your currentPoint
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            
            UIView.animate(withDuration: 0.2, delay: 0.1, animations: {
                self.backgroundColor = .clear
            })
        }
    }
    

}
