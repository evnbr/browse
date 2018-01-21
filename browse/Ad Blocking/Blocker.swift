//
//  Blocker.swift
//  browse
//
//  Created by Evan Brooks on 5/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//


import UIKit
import WebKit

let blockerListId = "blockerListId"

class Blocker: NSObject {
    static let shared = Blocker()
    
    var ruleList : WKContentRuleList?
    
    var isEnabled : Bool {
        return Settings.shared.blockAds.isOn
    }
    
    override init() {
        super.init()
    }
    
    func getList(_ callback: @escaping (WKContentRuleList?) -> ()) {
        if (ruleList != nil) {
            callback(ruleList)
        }
        else {
            buildList(callback)
        }
    }
    
    func buildList(_ done: @escaping (WKContentRuleList?) -> ()) {
        WKContentRuleListStore.default().getAvailableContentRuleListIdentifiers { (identifiers) in
            if identifiers != nil && identifiers!.contains(blockerListId) {
                print("existing rules found")
                WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: blockerListId, completionHandler: { (list, error) in
                    if let list : WKContentRuleList = list {
                        print("existing rules fetched")
                        self.ruleList = list
                        done(list)
                    } else {
                        print("existing rules failed to be fetched")
                        if (error != nil) { print(error as Any) }
                        done(nil)
                    }
                })
            } else {
                print("compiling rules...")
                do {
                    if let path = Bundle.main.path(forResource: "ultimateAdblockList", ofType: "json") {
                        let data = try String(contentsOfFile:path, encoding: String.Encoding.utf8)
                        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: blockerListId, encodedContentRuleList: data) { (list, error) in
                            if let list : WKContentRuleList = list {
                                print("rules compiled!")
                                self.ruleList = list
                                done(list)
                            } else {
                                print("rules failed to be compiled")
                                if (error != nil) { print(error as Any) }
                                done(nil)
                            }
                        }
                    } else {
                        print("rules file not found")
                        done(nil)
                    }
                } catch let error as NSError {
                    print("rules not compiled: ", error)
                    done(nil)
                }
            }
        }
    }
}
