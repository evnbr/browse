//
//  Blocker.swift
//  browse
//
//  Created by Evan Brooks on 5/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//


import UIKit
import WebKit

class Blocker: NSObject {
    
    private var fileNames = [
        "disconnect-advertising",
        "disconnect-analytics",
        "disconnect-content",
        "disconnect-social",
//        "ultimateAdblockList",
        "ultimateAdblockListCSS",
    ]
    private var lists : [ WKContentRuleList ] = []
    
    private var listsAreReady: Bool {
        return lists.count == fileNames.count
    }
    
    func getRules(_ callback: @escaping ([WKContentRuleList]) -> ()) {
        if listsAreReady {
            callback(lists)
            return
        }
        for name in fileNames {
            findList(name, completion: { list in
                if let list = list { self.lists.append(list) }
                if self.listsAreReady { callback(self.lists) }
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
        print("compiling rules '\(fileName)'")
        guard let path = Bundle.main.path(forResource: fileName, ofType: "json"),
            let data = try? String(contentsOfFile:path, encoding: String.Encoding.utf8) else {
                print("rules file not found")
                completion(nil)
                return
        }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: fileName, encodedContentRuleList: data) { (list, error) in
            if let list : WKContentRuleList = list {
                print("compiled '\(fileName)'")
                completion(list)
            } else {
                print("rules failed to be compiled")
                if let e = error { print(e) }
                completion(nil)
            }
        }
    }
}
