//
//  GradientColorChangeView.swift
//  browse
//
//  Created by Evan Brooks on 8/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

enum GradientColorChangeDirection {
    case topToBottom
    case bottomToTop
}

class GradientColorChangeView: UIView, CAAnimationDelegate {
    let duration: CFTimeInterval = 0.6

    var backgroundView: UIView!

    private var lastColor: UIColor = UIColor.clear

    override var backgroundColor: UIColor! {
        get {
            return lastColor
        }
        set {
            if let color = newValue {
                setBackground(to: color)
            } else {
                lastColor = .clear
            }
        }
    }

    var isLight: Bool {
        return lastColor.isLight
    }

    var initialHeight = Const.toolbarHeight

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundView = UIView(frame: bounds)
        backgroundView.clipsToBounds = true
        addSubview(backgroundView)
        sendSubview(toBack: backgroundView)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
            backgroundView.rightAnchor.constraint(equalTo: rightAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cancelColorChange() {
        backgroundView.backgroundColor = lastColor
    }


    func animateSimply(toColor: UIColor, direction: GradientColorChangeDirection ) -> Bool {
        if toColor.isEqual(lastColor) { return false }

        UIView.animate(withDuration: duration, delay: 0, options: .beginFromCurrentState, animations: {
            self.backgroundView.backgroundColor = toColor
            self.tintColor = toColor.isLight ? .white : .darkText
        })
        lastColor = toColor
        return true
    }

    private func setBackground(to newColor: UIColor) {
        cancelColorChange()
        self.backgroundView.backgroundColor = newColor
        self.tintColor = newColor.isLight ? .white : .darkText
        lastColor = newColor
    }

    @discardableResult
    func transitionBackground(to toColor: UIColor, from direction: GradientColorChangeDirection ) -> Bool {
        if toColor.isEqual(lastColor) { return false }

        return animateSimply(toColor: toColor, direction: direction)
    }

}
