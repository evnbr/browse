//
//  HistoryItem.swift
//  browse
//
//  Created by Evan Brooks on 10/13/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

class HistoryTree: NSObject {
    var root: HistoryItem?
    var current: HistoryItem?
}

class HistoryItem: NSObject {
    var browserTab: BrowserTab?
    
    let parent: HistoryItem?
    var children: [ HistoryItem ] = []
    
    var mirroredListItem: WKBackForwardListItem?
    var title: String?
    let url: URL
    
    var snapshot: UIImage?
    var topColor: UIColor?
    var bottomColor: UIColor?

    init(parent: HistoryItem?, url: URL) {
        self.parent = parent
        self.url = url
        
        super.init()
    }
    
    init(parent: HistoryItem?, from item: WKBackForwardListItem) {
        self.parent = parent
        self.url = item.url
        
        self.mirroredListItem = item

        super.init()
     }
}
