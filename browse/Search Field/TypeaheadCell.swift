//
//  TypeaheadCell.swift
//  browse
//
//  Created by Evan Brooks on 2/23/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class TypeaheadCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        let bg = UIView(frame: bounds)
        bg.backgroundColor = .darkTouch
        selectedBackgroundView = bg
        
        indentationWidth = 12.0
        indentationLevel = 0
        
        textLabel?.lineBreakMode = .byWordWrapping
        textLabel?.numberOfLines = 0
        textLabel?.font = .systemFont(ofSize: 18)
//        textLabel?.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 24).isActive = true
        layoutMargins = UIEdgeInsetsMake(12, 24, 12, 24)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    var isTitle : Bool {
        get {
            return textLabel!.font.pointSize > CGFloat(18)
        }
        set {
//            textLabel?.font = .systemFont(ofSize: newValue ? 24 : 18)
            textLabel?.alpha = newValue ? 0.3 : 1
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isTitle = false
    }
    
    override func tintColorDidChange() {
        textLabel?.textColor = tintColor
        selectedBackgroundView?.backgroundColor = tintColor.isLight ? .darkTouch : .lightTouch
    }

}
