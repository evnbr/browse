//
//  Constants.swift
//  browse
//
//  Created by Evan Brooks on 7/9/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

let CORNER_RADIUS: CGFloat = 8.0 //8.0
let SEARCH_RADIUS: CGFloat = 20.0
let THUMB_OFFSET_COLLAPSED: CGFloat = 44 //24.0 //40.0 // 28.0
let THUMB_TITLE: CGFloat = 12.0
let THUMB_H: CGFloat =  240//480.0
let THUMB_INSET: CGFloat = 0 // 4.0 //8.0
let PRESENT_TAB_BACK_SCALE: CGFloat = 1//0.97

let TAP_SCALE: CGFloat = 1.0 //0.97

let BUTTON_HEIGHT: CGFloat = 44

class Constants: NSObject {

    let toolbarHeight: CGFloat
    let statusHeight: CGFloat

    var thumbRadius: CGFloat
    let textFieldFont: UIFont = .systemFont(ofSize: 18)
    let thumbTitleFont: UIFont = .systemFont(ofSize: 17)
//    let thumbTitleFont : UIFont = .systemFont(ofSize: 14.0, weight: .medium)

    var cardRadius: CGFloat

    let shadowRadius: CGFloat = 32
    let shadowOpacity: Float = 0.4

    override init() {
        let topInset = UIApplication.shared.keyWindow?.safeAreaInsets.top
        let isX = topInset != nil && topInset! > CGFloat(0.0)
        toolbarHeight = isX ? 80 : 40
        statusHeight = isX ? 44 : 22
        thumbRadius = isX ? 38 : 16
        cardRadius = isX ? 38 : 4

        super.init()
    }
}

let Const = Constants()
