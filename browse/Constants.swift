//
//  Constants.swift
//  browse
//
//  Created by Evan Brooks on 7/9/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

let CORNER_RADIUS : CGFloat = 8.0 //8.0
let SEARCH_RADIUS : CGFloat = 18.0
let THUMB_OFFSET_COLLAPSED : CGFloat = 8.0 //40.0 // 28.0
let THUMB_TITLE : CGFloat = 12.0
let THUMB_H : CGFloat =  640//480.0
let THUMB_INSET : CGFloat = 0// 4.0 //8.0
let PRESENT_TAB_BACK_SCALE : CGFloat = 1//0.97

let TAP_SCALE : CGFloat = 1.0 //0.97

class Const: NSObject {
    static let shared = Const()
    
    var toolbarHeight: CGFloat
    var statusHeight: CGFloat
    
    var thumbRadius: CGFloat
    var thumbTitle : UIFont = UIFont.systemFont(ofSize: 15.0, weight: .regular)

    var cardRadius: CGFloat
    
    var shadowRadius: CGFloat = 8
    var shadowOpacity: Float = 0.4
    var buttonHeight: CGFloat = 40

    override init() {
        let topInset = UIApplication.shared.keyWindow?.safeAreaInsets.top
        let isX = topInset != nil && topInset! > CGFloat(0.0)
        toolbarHeight = isX ? 72 : 40
        statusHeight = isX ? 44 : 22
        thumbRadius = isX ? 32 : 16
        cardRadius = isX ? 38 : 4

        super.init()
    }
}
