//
//  Constants.swift
//  browse
//
//  Created by Evan Brooks on 7/9/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

// Webview
//let Const.shared.toolbarHeight     : CGFloat = 40.0
//let Const.shared.statusHeight      : CGFloat = 22.0
let CORNER_RADIUS : CGFloat = 8.0 //8.0
//let Const.shared.cardRadius   : CGFloat = 8.0 //8.0
let SEARCH_RADIUS : CGFloat = 18.0
//let THUMB_RADIUS  : CGFloat = 16.0

// Tab Switcher
let THUMB_H : CGFloat = 180.0
let PRESENT_TAB_BACK_SCALE : CGFloat = 1//0.97

let TAP_SCALE : CGFloat = 0.97

class Const: NSObject {
    static let shared = Const()
    
    var toolbarHeight : CGFloat
    var statusHeight : CGFloat
    var thumbRadius: CGFloat
    var cardRadius: CGFloat
    
    override init() {
        let isX = true
        toolbarHeight = isX ? 48 : 40
        statusHeight = isX ? 44 : 22
        thumbRadius = isX ? 32 : 16
        cardRadius = isX ? 40 : 8

        super.init()
    }
}
