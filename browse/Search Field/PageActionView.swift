//
//  PageActionView.swift
//  browse
//
//  Created by Evan Brooks on 3/5/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class PageActionView: UIView {

    private var label: UILabel!
    public var delegate: PageActionHandler?
    
    private var bookmarkButton : BookmarkButton!
    
    var title : String? {
        get { return label.text }
        set { label.text = newValue }
    }
    
    var isBookmarked : Bool {
        get { return bookmarkButton.isSelected }
        set { bookmarkButton.isSelected = newValue }
    }
    var isBookmarkEnabled : Bool {
        get { return bookmarkButton.isEnabled }
        set { bookmarkButton.isEnabled = newValue }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self

        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        
        label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Page title"
        label.alpha = 0.5
        addSubview(label)
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .leading
        stack.distribution = .fillEqually
        stack.spacing = 24.0
        addSubview(stack)
        
        label.leftAnchor.constraint(equalTo: leftAnchor, constant: 24).isActive = true
        label.rightAnchor.constraint(equalTo: rightAnchor, constant: -24).isActive = true
        stack.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -12).isActive = true

        stack.leftAnchor.constraint(equalTo: leftAnchor, constant: 16).isActive = true
        stack.rightAnchor.constraint(equalTo: rightAnchor, constant: -16).isActive = true
        label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6).isActive = true
        stack.heightAnchor.constraint(equalToConstant: 48).isActive = true
        
        stack.addArrangedSubview(LargeIconButton(icon: UIImage(named: "refresh")) {
            self.delegate?.refresh()
        })
        bookmarkButton = BookmarkButton() {
            self.delegate?.bookmark()
        }
        stack.addArrangedSubview(bookmarkButton)
        stack.addArrangedSubview(LargeIconButton(icon: UIImage(named: "share")) {
            self.delegate?.share()
        })
        stack.addArrangedSubview(LargeIconButton(icon: UIImage(named: "copy")) {
            self.delegate?.copy()
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = tintColor
    }
}

extension PageActionView : PageActionHandler {
    func refresh() { print("Set PageAction delegate") }
    func bookmark() { print("Set PageAction delegate") }
    func share() { print("Set PageAction delegate") }
    func copy() { print("Set PageAction delegate") }
}

protocol PageActionHandler {
    func refresh()
    func bookmark()
    func share()
    func copy()
}
