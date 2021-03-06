//
//  ToolbarIconButton.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ToolbarIconButton: ToolbarTouchView {

    var iconView: UIImageView!

    var isEnabled: Bool {
        get { return self.alpha == 1.0 }
        set { self.alpha = newValue ? 1 : 0.3 }
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 60, height: BUTTON_HEIGHT)
    }

    init(icon: UIImage?, onTap: ToolbarButtonAction? = nil) {
        super.init(frame: CGRect(x: 0, y: 0, width: 60, height: BUTTON_HEIGHT), onTap: onTap)

        let iconTemplate = icon?.withRenderingMode(.alwaysTemplate)
        iconView = UIImageView(image: iconTemplate)

        addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.center = self.center

        iconView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        iconView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

        self.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LargeIconButton: ToolbarIconButton {
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 64, height: 64)
    }
}
