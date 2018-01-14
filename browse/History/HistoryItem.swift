//
//  HistoryPage.swift
//  browse
//
//  Created by Evan Brooks on 10/13/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

class HistoryTree: NSObject {
    var root: HistoryPage?
    var current: HistoryPage?
}

class HistoryPage: NSObject {
    var browserTab: BrowserTab?
    
    let parent: HistoryPage?
    var children: [ HistoryPage ] = []
    
    var mirroredListItem: WKBackForwardListItem?
    var title: String?
    let url: URL
    
    var snapshot: UIImage?
    var topColor: UIColor?
    var bottomColor: UIColor?

    init(parent: HistoryPage?, url: URL) {
        self.parent = parent
        self.url = url
        
        super.init()
    }
    
    init(parent: HistoryPage?, from item: WKBackForwardListItem) {
        self.parent = parent
        self.url = item.url
        
        self.mirroredListItem = item

        super.init()
     }
}
