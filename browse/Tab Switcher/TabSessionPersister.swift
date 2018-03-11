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
fileprivate let kTabTitle = "tabTitle"
fileprivate let kTabURL = "tabURL"
fileprivate let kTabUUID = "tabUUID"

class TabSessionPersister: NSObject {
    static let shared = TabSessionPersister()
    
    func save(_ tabs : [ BrowserTab ], presentedIndex: Int) {
        let tabInfo = tabs.map { $0.restorableInfo }
        let dicts = tabInfo.map { $0.nsDictionary }
        UserDefaults.standard.setValue(dicts, forKey: kTabList)
        UserDefaults.standard.set(presentedIndex, forKey: kPresentedIndex)
        
        tabInfo.forEach { t in
            if let image = t.image, let id = t.id {
                saveImage(image, as: id)
            }
        }
    }
    
    func restoreIndex() -> Int? {
        let index = UserDefaults.standard.value(forKey: "presentedTabIndex") as? Int
        if let index = index, index > -1 { return index }
        else { return nil }
    }
    
    func restore() -> [ TabInfo ] {
        if let openTabs = UserDefaults.standard.value(forKey: kTabList) as? [ [ String : Any ]] {
            return openTabs.map { dict in
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
                
                let restoredId = dict[kTabUUID] as? String
                let image = restoreImage(named: restoredId)
                
                return TabInfo(
                    title: title,
                    urlString: urlString,
                    topColor: topColor,
                    bottomColor: bottomColor,
                    id: restoredId,
                    image: image
                )
                
            }
        }
        return []
    }
    
    @discardableResult
    func saveImage(_ image: UIImage, as name: String) -> Bool {
        guard let data = UIImageJPEGRepresentation(image, 1) ?? UIImagePNGRepresentation(image) else {
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            try data.write(to: directory.appendingPathComponent("\(name).png")!)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    func restoreImage(named name: String?) -> UIImage? {
        guard let name = name else { return nil }
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent("\(name).png").path)
        }
        return nil
    }
}

struct TabInfo {
    var title : String
    var urlString : String
    var topColor: UIColor
    var bottomColor: UIColor
    var id : String?
    var image : UIImage?
    
    var nsDictionary : NSDictionary {
        return NSDictionary(dictionary: [
            kTabTitle : title,
            kTabURL : urlString,
            kTabUUID: id ?? "",
            "topColor" : topColor.getRGB(),
            "bottomColor" : bottomColor.getRGB(),
        ])
    }
}
