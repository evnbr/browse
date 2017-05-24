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
            
            var newFrame = label.frame
            newFrame.origin.x = (isSearch || isSecure) ? 24 : 0
            label.frame = newFrame
        
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
        action = onTap
        super.init(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        backgroundColor = .clear
        
        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        lock = UIImageView(image: lockImage)
        addSubview(lock)
        
        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
        magnify = UIImageView(image: magnifyImage)
        addSubview(magnify)


        label.text = "Hey"
        label.sizeToFit()
        
        
        addSubview(label)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(doAction))
        tap.numberOfTapsRequired = 1
        tap.isEnabled = true
        tap.cancelsTouchesInView = false
        
        addGestureRecognizer(tap)
        

//        sizeToFit()
    }
    
    func doAction() {
        print("tapped")
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
            backgroundColor = .cyan
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            // do something with your currentPoint
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            
            UIView.animate(withDuration: 0.1, delay: 0.1, animations: {
                self.backgroundColor = .clear
            })
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            
            UIView.animate(withDuration: 0.1, delay: 0.1, animations: {
                self.backgroundColor = .clear
            })
        }
    }
    

}
