//
//  ColorToolbarView.swift
//  browse
//
//  Created by Evan Brooks on 6/13/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ColorToolbarView: GradientColorChangeView {
    let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        tintColor = .white
        clipsToBounds = true

        autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
//        translatesAutoresizingMaskIntoConstraints = false

        stackView.axis  = .horizontal
        stackView.distribution  = .fill
        stackView.alignment = .top
        stackView.spacing = 0.0

        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        let toolbarInset: CGFloat = 8.0
        
        let guide = self.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: guide.leadingAnchor,
                constant: toolbarInset),
            stackView.trailingAnchor.constraint(
                equalTo: guide.trailingAnchor,
                constant: -toolbarInset),
            stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: TOOLBAR_TOP_MARGIN)
        ])
        
        backgroundView.alpha = 0.96
    }

    var toolbarItems: [ UIView ] {
        get {
            return stackView.subviews
        }
        set {
            stackView.subviews.forEach { $0.removeFromSuperview() }
            for item in newValue {
                stackView.addArrangedSubview(item)
            }
        }
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        subviews.forEach { $0.tintColor = tintColor }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
