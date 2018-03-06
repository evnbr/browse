//
//  SearchTextView.swift
//  browse
//
//  Created by Evan Brooks on 3/1/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class SearchTextView: UITextView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        let shareItem = UIMenuItem(title: "Share...", action: #selector(share(_:)))
        UIMenuController.shared.menuItems?.append(shareItem)
        UIMenuController.shared.update()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func share(_ sender: Any?) {
        print("tapped share")
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(select(_:)):
            return super.canPerformAction(action, withSender:sender)
        case #selector(selectAll(_:)):
            return super.canPerformAction(action, withSender:sender)
        case #selector(copy(_:)):
            return super.canPerformAction(action, withSender:sender)
        case #selector(paste(_:)):
            return super.canPerformAction(action, withSender:sender)
        case #selector(share(_:)):
            return true
        default:
            return false
        }
    }

}
