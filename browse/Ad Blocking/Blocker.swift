//
//  Blocker.swift
//  browse
//
//  Created by Evan Brooks on 5/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//


import UIKit
import WebKit

fileprivate let hostsFileName = "ultimateAdblockList"
fileprivate let cssFileName = "ultimateAdblockListCSS"

class Blocker: NSObject {
    private var hostRules : WKContentRuleList?
    private var cssRules : WKContentRuleList?

    var isEnabled : Bool {
        return Settings.shared.blockAds.isOn
    }
    
    private var listsAreReady: Bool {
        return hostRules != nil && cssRules != nil
    }
    
    private var loadedLists: [WKContentRuleList] {
        guard let h = hostRules, let c = cssRules else { return [] }
        return [ h, c ]
    }
    
    func getRules(_ callback: @escaping ([WKContentRuleList]) -> ()) {
        if listsAreReady { callback(loadedLists) }
        else {
            findList(hostsFileName, completion: { list in
                self.hostRules = list
                if self.listsAreReady { callback(self.loadedLists) }
            })
            findList(cssFileName, completion: { list in
                self.cssRules = list
                if self.listsAreReady { callback(self.loadedLists) }
            })
        }
    }
    
    
    func findList(_ fileName : String, completion: @escaping (WKContentRuleList?) -> ()) {
        WKContentRuleListStore.default().getAvailableContentRuleListIdentifiers { (identifiers) in
            if identifiers != nil && identifiers!.contains(fileName) {
                WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: fileName, completionHandler: { (list, error) in
                    if let list : WKContentRuleList = list {
                        completion(list)
                    } else {
                        print("existing rules failed to be fetched")
                        if let e = error { print(e) }
                        if let e = error as? WKError, e.code == WKError.contentRuleListStoreVersionMismatch {
                            self.compileList(fileName, completion: completion)
                        }
                        else {
                            completion(nil)
                        }
                    }
                })
            } else {
                self.compileList(fileName, completion: completion)
            }
        }
    }
    
    func compileList(_ fileName : String, completion: @escaping (WKContentRuleList?) -> ()) {
        print("compiling rules...")
        guard let path = Bundle.main.path(forResource: fileName, ofType: "json"),
            let data = try? String(contentsOfFile:path, encoding: String.Encoding.utf8) else {
                print("rules file not found")
                completion(nil)
                return
        }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: fileName, encodedContentRuleList: data) { (list, error) in
            if let list : WKContentRuleList = list {
                completion(list)
            } else {
                print("rules failed to be compiled")
                if let e = error { print(e) }
                completion(nil)
            }
        }
    }
}
