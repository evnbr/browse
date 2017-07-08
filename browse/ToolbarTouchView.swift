//
//  ToolbarTouchView.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ToolbarTouchView: UIView {

    var action: () -> Void
    var tapColor : UIColor = UIColor.black.withAlphaComponent(0.08)
    var touchCircle : UIView!
    
    override var frame : CGRect {
        didSet {
            layer.cornerRadius = frame.height / 2
            touchCircle?.frame = CGRect(x: 0, y: 0, width: frame.width + 20, height: frame.width + 20)
            touchCircle?.layer.cornerRadius = frame.width / 2
        }
    }
    
    
    init(frame: CGRect, onTap: @escaping () -> Void) {
        action = onTap

        super.init(frame: frame)
        backgroundColor = .clear
//        layer.cornerRadius = 8.0
        layer.cornerRadius = frame.height / 2
        layer.masksToBounds = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(doAction))
        tap.numberOfTapsRequired = 1
        tap.isEnabled = true
        tap.cancelsTouchesInView = false
        
        touchCircle = UIView(frame: CGRect(x: 0, y: 0, width: frame.width + 20, height: frame.width + 20))
        touchCircle.layer.masksToBounds = true
        touchCircle.center = self.center
        touchCircle.layer.cornerRadius = frame.width / 2
        touchCircle.isUserInteractionEnabled = false
        touchCircle.alpha = 0
        
        addSubview(touchCircle)
        sendSubview(toBack: touchCircle)
        
        addGestureRecognizer(tap)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func doAction() {
        action()
        deSelect()
    }
    
    override func tintColorDidChange() {
        tapColor = tintColor.isLight
            ? UIColor.black.withAlphaComponent(0.1)
            : UIColor.white.withAlphaComponent(0.3)
        
        self.touchCircle.backgroundColor = self.tapColor
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
//            backgroundColor = tapColor

            touchCircle.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            touchCircle.center = touches.first!.location(in: self)
            
            let endScale = (frame.width + 2 * abs(frame.width / 2 - touchCircle.center.x)) / frame.width
            
            UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseIn, animations: {
                self.touchCircle.alpha = 1
                self.touchCircle.transform = CGAffineTransform(scaleX: endScale, y: endScale)
            })
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            // do something with your currentPoint
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        deSelect()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        deSelect()
    }

    
    func deSelect() {
        UIView.animate(withDuration: 0.6, delay: 0.0, options: .curveEaseInOut, animations: {
            self.backgroundColor = .clear
            self.touchCircle.alpha = 0
        })
    }

}
