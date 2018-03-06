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
    var tapColor : UIColor = .lightTouch
    
    override var intrinsicContentSize: CGSize {
        return frame.size
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        radius = frame.height / 2
    }
    
    
    init(frame: CGRect, onTap: @escaping () -> Void) {
        action = onTap

        super.init(frame: frame)
        backgroundColor = .clear
        layer.masksToBounds = true
        radius = frame.height / 2
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(doAction))
        tap.numberOfTapsRequired = 1
        tap.isEnabled = true
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        
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
        super.tintColorDidChange()
        tapColor = tintColor.isLight ? .darkTouch : .lightTouch
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            select()
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
        })
    }
    func select() {
        tapColor = tintColor.isLight ? .darkTouch : .lightTouch
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: {
            self.backgroundColor = self.tapColor
        })
    }

}
