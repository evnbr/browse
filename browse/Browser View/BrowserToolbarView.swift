//
//  BrowserToolbarView.swift
//  browse
//
//  Created by Evan Brooks on 7/12/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class BrowserToolbarView: ColorToolbarView {

    var heightConstraint: NSLayoutConstraint!
    var backButton: ToolbarIconButton!
    var stopButton: ToolbarIconButton!
    var tabButton: ToolbarIconButton!
    var searchField: ToolbarSearchField!

    var text: String? {
        get { return searchField.text }
        set { searchField.text = newValue }
    }
    var progress: CGFloat {
        get { return searchField.progress }
        set { searchField.progress = newValue }
    }

    var contentsAlpha: CGFloat {
        get { return searchField.alpha }
        set {
            searchField.alpha = newValue
            backButton.alpha = newValue
            tabButton.alpha = newValue
        }
    }

    var isSecure: Bool {
        get { return searchField.isSecure }
        set { searchField.isSecure = newValue }
    }

    var isSearch: Bool {
        get { return searchField.isSearch }
        set { searchField.isSearch = newValue }
    }

    var isLoading: Bool {
        get { return searchField.isLoading }
        set {
            searchField.isLoading = newValue
            isStopVisible = newValue
        }
    }

    private var isStopVisible: Bool {
        get { return self.stopButton.isEnabled }
        set {
            UIView.animate(withDuration: 0.25) {
                self.stopButton.isEnabled = newValue
                self.stopButton.tintColor = newValue ? nil : .clear
                self.stopButton.scale = newValue ? 1 : 0.6
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

//        let blur = PlainBlurView(frame: bounds)
//        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        addSubview(blur)
//        sendSubview(toBack: blur)

        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: Const.toolbarHeight)
        heightConstraint.isActive = true

        searchField = ToolbarSearchField()
        backButton = ToolbarIconButton(icon: UIImage(named: "back"))
        tabButton = ToolbarIconButton(icon: UIImage(named: "action"))

        stopButton = searchField.stopButton
        toolbarItems = [backButton, searchField, tabButton]

        // Initial values
        isLoading = false
        progress = 1
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        subviews.forEach { (v) in
            v.tintColor = tintColor
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
