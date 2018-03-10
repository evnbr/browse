//
//  TabSessionPersister.swift
//  browse
//
//  Created by Evan Brooks on 3/10/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

fileprivate let kTabList = "openTabList"
fileprivate let kPresentedIndex = "presentedTabIndex"
fileprivate let kTabTitle = "presentedTabIndex"
fileprivate let kTabURL = "presentedTabIndex"

class TabSessionPersister: NSObject {
    static let shared = TabSessionPersister()
    
    func save(_ tabs : [ BrowserTab ], presentedIndex: Int) {
        let info = tabs.map { tab in tab.restorableInfo.nsDictionary }
        UserDefaults.standard.setValue(info, forKey: kTabList)
        UserDefaults.standard.set(presentedIndex, forKey: kPresentedIndex)
    }
    
    func restoreIndex() -> Int? {
        let index = UserDefaults.standard.value(forKey: "presentedTabIndex") as? Int
        if let index = index, index > -1 { return index }
        else { return nil }
    }
    
    func restore() -> [ TabInfo ] {
        if let openTabs = UserDefaults.standard.value(forKey: kTabList) as? [ [ String : Any ]] {
            let converted : [ TabInfo ] = openTabs.map { dict in
                let title = dict[kTabTitle] as? String ?? ""
                let urlString = dict[kTabURL] as? String ?? ""
                var topColor : UIColor
                var bottomColor : UIColor
                if let rgb = dict["topColor"] as? [ CGFloat ] {
                    topColor = UIColor(r: rgb[0], g: rgb[1], b: rgb[2] )
                }
                else {
                    topColor = UIColor.white
                }
                if let rgb = dict["bottomColor"] as? [ CGFloat ] {
                    bottomColor = UIColor(r: rgb[0], g: rgb[1], b: rgb[2] )
                }
                else {
                    bottomColor = UIColor.white
                }
                
                return TabInfo(
                    title: title,
                    urlString: urlString,
                    topColor: topColor,
                    bottomColor: bottomColor
                )
            }
            return converted
        }
        return []
    }
}

struct TabInfo {
    var title : String
    var urlString : String
    var topColor: UIColor
    var bottomColor: UIColor
    
    var nsDictionary : NSDictionary {
        return NSDictionary(dictionary: [
            kTabTitle : title,
            kTabURL : urlString,
            "topColor" : topColor.getRGB(),
            "bottomColor" : bottomColor.getRGB(),
        ])
    }
}
