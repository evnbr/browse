//
//  ColorStatusBar.swift
//  browse
//
//  Created by Evan Brooks on 5/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

extension UIVisualEffectView {
    public convenience init(frame: CGRect, isTransparent: Bool) {
        
        self.init(effect: UIBlurEffect(style: .dark))
        self.frame = frame
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // TODO: gross workaround to not have lightening effect.
        // could be more robust, make sure if v is _UIVisualEffectFilterView
        for v in subviews {
            
            if v.backgroundColor != nil {
                v.backgroundColor = nil
            }
        }

    }
}

class ColorStatusBarView : UIView {
    var blurView : UIVisualEffectView!
    
    init() {
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size:CGSize(width: UIScreen.main.bounds.size.width, height: STATUS_H)
        )

        super.init(frame: rect)
        
        self.autoresizingMask = [.flexibleWidth]
        self.backgroundColor = .red
        
//        let overlay = UIView(frame: self.frame)
//        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.1)
//        self.addSubview(overlay)
    }
    
    convenience init(color: UIColor) {
        self.init()
        self.backgroundColor = color
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
