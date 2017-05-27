//
//  Blocker.swift
//  browse
//
//  Created by Evan Brooks on 5/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//
//  Reference: https://adblockplus.org/filter-cheatsheet
//  Uses peter lowe's host list from: https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml
//  TODO:
//    - Update list on demand?
//    - Support partial matches and other abp features

import UIKit

class Blocker: NSObject {
    static let shared = Blocker()

    var sitesToBlock : Set<String>!
    
    override init() {
        super.init()
        sitesToBlock = loadSites()
    }
    
    func shouldBlock(_ url : URL) -> Bool {
        if let host = url.host {
            let components = host.components(separatedBy: ".")
            
            var hostIsBad = false
            
            // tries "test.com", "ads.test.com", "sketchy.ads.test.com"
            let _ = components.reversed().reduce("", { result, elmt in
                if hostIsBad { return result }
                if result == "" { return elmt }
                if sitesToBlock.contains(result) { hostIsBad = true }

                return elmt + "." + result
            })
            return hostIsBad
        }
        return false
    }
    
    func loadSites() -> Set<String> {
        
        do {
            if let path = Bundle.main.path(forResource: "plowe", ofType: "txt"){
                let data = try String(contentsOfFile:path, encoding: String.Encoding.utf8)
                let arrayOfStrings = data.components(separatedBy: "\n")
                
                let siteSet : Set<String> = Set(arrayOfStrings)

                return siteSet
            }
        } catch let error as NSError {
            print(error)
        }
        return []

    }
}
