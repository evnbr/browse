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
        indentationLevel = 1
        
        textLabel?.lineBreakMode = .byWordWrapping
        textLabel?.numberOfLines = 0
        textLabel?.font = .systemFont(ofSize: 18)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    override func tintColorDidChange() {
        textLabel?.textColor = tintColor
        selectedBackgroundView?.backgroundColor = tintColor.isLight ? .darkTouch : .lightTouch
    }

}
