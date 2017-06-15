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
        
        self.init(effect: UIBlurEffect(style: .light))
        self.frame = frame
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // TODO: gross workaround to not have lightening effect.
        // could be more robust, make sure if v is _UIVisualEffectFilterView
        for v in subviews {
            
            if v.backgroundColor != nil {
                v.backgroundColor = nil
            }
            
            //            let sat = v.value(forKey: "_saturateFilter")
            //            let colorOffset = v.value(forKey: "_colorOffsetFilter")
            //            let blur = v.value(forKey: "_blurFilter")
        }

    }
}

class ColorStatusBarView : UIView {
    var inner : UIView!
    var back : UIView!
    var blurView : UIVisualEffectView!
    
    init() {
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:20)
        )

        super.init(frame: rect)
        
        self.autoresizingMask = [.flexibleWidth]
        self.backgroundColor = .clear
        
        back = UIView.init(frame: rect)
        back.autoresizingMask = [.flexibleWidth]
        back.backgroundColor = .white
//        back.alpha = 0.7
        self.addSubview(back)
        
//        blurView = UIVisualEffectView(frame: rect, isTransparent: true)
//        self.addSubview(blurView)
        
        inner = UIView()
        inner.frame = back.bounds
        inner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        inner.backgroundColor = .white
//        back.addSubview(inner)
        back.clipsToBounds = true
        
        self.clipsToBounds = true
        
//        isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
