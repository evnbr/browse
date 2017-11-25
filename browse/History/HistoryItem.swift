//
//  HistoryItem.swift
//  browse
//
//  Created by Evan Brooks on 10/13/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

class HistorTree: NSObject {
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
