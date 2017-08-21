//
//  ProgressToolbar.swift
//  browse
//
//  Created by Evan Brooks on 7/12/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ProgressToolbar: BrowseToolbar {
    
    let progressView: UIProgressView = UIProgressView(progressViewStyle: .default)
    
    
    var progress : Float {
        get {
            return progressView.progress
        }
        set {
            progressView.alpha = 1.0
            let isIncreasing = progressView.progress < newValue
            
            progressView.setProgress(Float(newValue), animated: isIncreasing)
            if (newValue >= 1.0) {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.progress = 1.0
                    self.progressView.alpha = 0
                }, completion: { (finished) in
                    self.progressView.setProgress(0.0, animated: false)
                })
            }
            
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 20),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.white.withAlphaComponent(0.25)
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)
        addSubview(progressView)
        sendSubview(toBack: progressView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
