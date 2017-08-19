//
//  Blocker.swift
//  browse
//
//  Created by Evan Brooks on 5/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//


import UIKit
import WebKit

let EASYLIST_ID = "easylistrules"

class Blocker: NSObject {
    static let shared = Blocker()
    
    var ruleList : WKContentRuleList?
    
    var isEnabled : Bool {
        return Settings.shared.blockAds.isOn
    }
    
    override init() {
        super.init()
        getList()
    }
    
    func getList() {
        WKContentRuleListStore.default().getAvailableContentRuleListIdentifiers { (identifiers) in
            if identifiers != nil && identifiers!.contains(EASYLIST_ID) {
                print("existing rules found")
                WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: EASYLIST_ID, completionHandler: { (list, error) in
                    if let list : WKContentRuleList = list {
                        print("existing rules fetched")
                        self.ruleList = list
                    } else {
                        print("existing rules failed to be fetched")
                        if (error != nil) { print(error as Any) }
                    }
                })
            } else {
                print("compiling rules...")
                do {
                    if let path = Bundle.main.path(forResource: "easylist", ofType: "json") {
                        let data = try String(contentsOfFile:path, encoding: String.Encoding.utf8)
                        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: EASYLIST_ID, encodedContentRuleList: data) { (list, error) in
                            if let list : WKContentRuleList = list {
                                print("rules compiled!")
                                self.ruleList = list
                            } else {
                                print("rules failed to be compiled")
                                if (error != nil) { print(error as Any) }
                            }
                        }
                    } else {
                        print("rules file not found")
                    }
                } catch let error as NSError {
                    print("rules not compiled: ", error)
                }
            }
        }
    }
}
