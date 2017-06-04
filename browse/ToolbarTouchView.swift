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

    init(frame: CGRect, onTap: @escaping () -> Void) {
        action = onTap

        super.init(frame: frame)
        backgroundColor = .clear
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(doAction))
        tap.numberOfTapsRequired = 1
        tap.isEnabled = true
        tap.cancelsTouchesInView = false
        
        addGestureRecognizer(tap)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func doAction() {
        action()
    }
    
    override func tintColorDidChange() {
        tapColor = tintColor.isLight
            ? UIColor.black.withAlphaComponent(0.1)
            : UIColor.white.withAlphaComponent(0.15)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            backgroundColor = tapColor
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
