//
//  FloatButton.swift
//  browse
//
//  Created by Evan Brooks on 1/28/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class FloatButton: UIView {

    var action: () -> Void
    var tapColor : UIColor = .darkGray
    var iconView : UIImageView!
    
    init(frame: CGRect, icon: UIImage?, onTap: @escaping () -> Void) {
        action = onTap
        
        super.init(frame: frame)
        backgroundColor = .black
        translatesAutoresizingMaskIntoConstraints = false
        tintColor = .white
        
        layer.masksToBounds = true
        radius = frame.height / 2
        
        let iconTemplate = icon?.withRenderingMode(.alwaysTemplate)
        iconView = UIImageView(image: iconTemplate)
        
        addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.center = self.center
        
        iconView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        iconView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        
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
            self.backgroundColor = .black
        })
    }
    func select() {
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: {
            self.backgroundColor = self.tapColor
        })
    }
}
