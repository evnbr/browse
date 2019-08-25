//
//  LocationLabel.swift
//  browse
//
//  Created by Evan Brooks on 3/23/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import UIKit

enum LocationLabelMode: Int {
    case blank
    case search
    case lock
}

class LocationLabel: UIView {
    private var lockIcon: UIImageView!
    private var searchIcon: UIImageView!
    private var label = UILabel()
    
    private var shouldShowLock : Bool = false
    
    var text: String? {
        get {
            return label.text
        }
        set {
            if newValue == "" {
                label.text = "Where to?"
            }
            else if label.text != newValue {
                label.text = newValue
            }
            var size = label.sizeThatFits(bounds.size)
            size.width = min(size.width, bounds.width - searchIcon.bounds.width) // room for decorations
            label.bounds.size = size
            self.sizeToFit()
        }
    }
    
    var showLock : Bool {
        get { return shouldShowLock }
        set {
            shouldShowLock = newValue
            lockIcon.isHidden = !shouldShowLock || showSearch
        }
    }
    
    var showSearch : Bool {
        get { return !searchIcon.isHidden }
        set { searchIcon.isHidden = !newValue }
    }
    
    init() {
        super.init(frame: .zero)
        //        let magnifyImage = UIImage(named: "magnify")!.withRenderingMode(.alwaysTemplate)
//        let lockImage = UIImage(named: "lock")!.withRenderingMode(.alwaysTemplate)
        
        let lockImage = UIImage(systemName: "lock.slash.fill")
        let magnifyImage = UIImage(systemName: "magnifyingglass")

//        let weight = UIImage.SymbolConfiguration(weight: .medium)
        lockIcon = UIImageView(image: lockImage)
        lockIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .small)
        

        searchIcon = UIImageView(image: magnifyImage)
        searchIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .small)
        
        label.text = "Where to?"
        label.font = Const.thumbTitleFont
        label.adjustsFontSizeToFitWidth = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        
        let labelContent = UIStackView()
        labelContent.axis = .horizontal
        labelContent.distribution = .fill
        labelContent.alignment = .center //.firstBaseline
        labelContent.spacing = 4.0
        
        labelContent.addArrangedSubview(lockIcon)
        labelContent.addArrangedSubview(searchIcon)
        labelContent.addArrangedSubview(label)
        labelContent.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(labelContent, constraints: [
            labelContent.leftAnchor.constraint(equalTo: leftAnchor),
            labelContent.topAnchor.constraint(equalTo: topAnchor),
            labelContent.bottomAnchor.constraint(equalTo: bottomAnchor),
            labelContent.rightAnchor.constraint(equalTo: rightAnchor)
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = tintColor
    }
}
