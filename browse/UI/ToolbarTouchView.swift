//
//  ToolbarTouchView.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
typealias ToolbarButtonAction = () -> Void

class ToolbarTouchView: UIView {

    private var action: ToolbarButtonAction?
    private var tapColor: UIColor = .lightTouch
    private var tap: UITapGestureRecognizer?
    var baseColor: UIColor = .clear {
        didSet {
            backgroundColor = baseColor
        }
    }

    override var intrinsicContentSize: CGSize {
        return frame.size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        radius = 12 //frame.height / 2
    }

    init(frame: CGRect, onTap: ToolbarButtonAction? ) {
        super.init(frame: frame)
        if let action = onTap { setAction(action) }
        backgroundColor = baseColor
        layer.masksToBounds = true
        radius = frame.height / 2
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAction(_ action: @escaping ToolbarButtonAction) {
        if tap == nil { setupTapGesture() }
        self.action = action
    }

    @objc func doAction() {
        action?()
        deSelect()
    }

    func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(doAction))
        tap.numberOfTapsRequired = 1
        tap.isEnabled = true
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        addGestureRecognizer(tap)
        self.tap = tap
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        tapColor = tintColor.isLight ? .darkTouch : .lightTouch
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            select()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            // do something with your currentPoint
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        deSelect()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        deSelect()
    }

    func deSelect() {
        UIView.animate(withDuration: 0.6, delay: 0.0, options: .curveEaseInOut, animations: {
            self.backgroundColor = self.baseColor
        })
    }
    func select() {
        tapColor = tintColor.isLight ? .darkTouch : .lightTouch
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseIn, animations: {
            self.backgroundColor = self.tapColor
        })
    }

}
