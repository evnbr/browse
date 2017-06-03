//
//  Settings.swift
//  browse
//
//  Created by Evan Brooks on 5/27/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

struct SettingsSection {
    let title: String
    let items : [SettingsItem]
    
    var numberOfItems: Int {
        return items.count
    }
    
    subscript(index: Int) -> SettingsItem {
        return items[index]
    }
}

class SettingsItem : NSObject {
    var key: String
    var title: String
    var style: SettingsItemStyle
    var isOn: Bool {
        didSet {
            UserDefaults.standard.setValue(isOn, forKey: "settings_\(key)")
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: "adBlockSettingDidChange"), // TODO: don't send for every switch!
                object: nil)
        }
    }
    
    init(key: String, title: String, style: SettingsItemStyle = .plain, isOn: Bool = false) {
        self.key = key
        self.title = title
        self.style = style
        
        let stored = UserDefaults.standard.value(forKey: "settings_\(key)")
        if stored != nil {
            let storedState : Bool = stored as! Bool
            self.isOn = storedState
        } 
        else {
            self.isOn = isOn
        }
    }
}

enum SettingsItemStyle {
    case plain
    case toggle
}

class Settings: NSObject {
    static let shared = Settings()

    var sections : [SettingsSection] {
        get {
            let section1 = SettingsSection(title: "Web Content", items: [
                blockAds,
                blockSocial,
                ])
            
            let section2 = SettingsSection(title: "Browser Interface", items: [
                opt1,
                opt2
                ])
            
            return [section1, section2]
        }
    }
    
    var blockAds : SettingsItem
    var blockSocial : SettingsItem
    var opt1 : SettingsItem
    var opt2 : SettingsItem
    
    override init() {
        
        blockAds = SettingsItem(
            key: "blockAds",
            title: "Block Ads and Trackers",
            style: .toggle
        )
        
        blockSocial = SettingsItem(
            key: "blockSocial",
            title: "Block Social Media",
            style: .toggle
        )
        
        opt1 = SettingsItem(
            key: "matchColor",
            title: "Match color of page",
            style: .toggle,
            isOn: true
        )
        
        opt2 = SettingsItem(
            key: "restoreTab",
            title: "Restore Tab"
        )
        
        super.init()
        
    }
    
    
    

}
