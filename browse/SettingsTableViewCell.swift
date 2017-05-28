//
//  SettingsTableViewCell.swift
//  browse
//
//  Created by Evan Brooks on 5/27/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

//    var label = UILabel()
//    var toggle = UISwitch()
    
    var item: SettingsItem!
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggleSwitch(sender: UISwitch) {
        self.item.isOn = sender.isOn
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }


}
