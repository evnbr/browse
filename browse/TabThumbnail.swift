//
//  TabThumbnail.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class TabThumbnail: UIView {

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
                self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
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

}
