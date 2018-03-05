//
//  PlainBlurView.swift
//  browse
//
//  Created by Evan Brooks on 3/4/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class PlainBlurView: UIVisualEffectView {
    
    private var overlayView : UIView!
    
    var overlayColor: UIColor? {
        get { return overlayView.backgroundColor }
        set {  overlayView.backgroundColor = newValue }
    }
    
    var overlayAlpha: CGFloat {
        get { return overlayView.alpha }
        set { overlayView.alpha = newValue }
    }
    
    convenience init(frame: CGRect) {
        self.init(effect: UIBlurEffect(style: .light))
        self.frame = frame
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // TODO: workaround to not have lightening effect.
        // could be more robust, make sure if v is _UIVisualEffectFilterView
        let bgViews = subviews.filter { v -> Bool in return v.backgroundColor != nil }
        overlayView = bgViews[0]
        overlayAlpha = 0
        overlayColor = nil
    }

}

