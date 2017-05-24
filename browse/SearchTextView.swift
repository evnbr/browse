//
//  SearchTextView.swift
//  browse
//
//  Created by Evan Brooks on 5/20/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class SearchTextView: UITextView {
    
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
        default:
            return false
        }

    }

}
