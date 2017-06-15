//
//  TabThumbnail.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class TabThumbnail: UIView {

    var snap : UIView!
    
    override var frame : CGRect {
        didSet {
            if snap != nil {
                let aspect = snap.frame.size.height / snap.frame.size.width
                let W = self.frame.size.width
                snap.frame = CGRect(x: 0, y: 0, width: W, height: aspect * W )
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 5.0
        clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            UIView.animate(withDuration: 0.15, animations: {
                self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            })
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
                self.transform = .identity
            })
        }
    }
    
    func unSelect() {
        UIView.animate(withDuration: 0.2, delay: 0.1, animations: {
            self.transform = .identity
        })

    }
    
    func setSnapshot(_ newSnapshot : UIView) {
        snap?.removeFromSuperview()
        
        snap = newSnapshot
        
        let aspect = snap.frame.size.height / snap.frame.size.width
        let W = self.frame.size.width
        snap.frame = CGRect(x: 0, y: 0, width: W, height: aspect * W )
        
        //        snapshot.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        self.addSubview(snap)
        //        let h = NSLayoutConstraint(item: snapshot, attribute: .height, relatedBy: .equal, toItem: thumb, attribute: .height, multiplier: 1, constant: 1)
        //        let w = NSLayoutConstraint(item: snapshot, attribute: .width, relatedBy: .equal, toItem: thumb, attribute: .width, multiplier: 1, constant: 1)
        //        thumb.addConstraints([w, h])

    }

}
