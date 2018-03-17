//
//  HistoryManager.swift
//  browse
//
//  Created by Evan Brooks on 3/15/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import CoreData
import WebKit

class HistoryManager: NSObject {
    static let shared = HistoryManager()
    
    var snapshotCache: [ UUID : UIImage ] = [:]
    private var historyPageMap: [ WKBackForwardListItem : HistoryItem ] = [:]

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HistoryModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    func page(from item: WKBackForwardListItem) -> HistoryItem? {
        return historyPageMap[item]
    }

    func sync(tab: Tab, with list: WKBackForwardList) {
        guard let currentWKItem = list.currentItem else { return }
        var anItem = historyPageMap[currentWKItem]
        if anItem == nil {
            if let backWKItem = list.backItem,
                let backItem = historyPageMap[backWKItem],
                backItem == tab.currentItem {
                // We went forward, link these pages together
                anItem = addPage(from: currentWKItem, parent: tab.currentItem)
                if let it = anItem { tab.currentItem?.addToForwardItems(it) }
            }
            else {
                // Create a new entry (probably restored)
                print("unknown parent")
                anItem = addPage(from: currentWKItem, parent: nil)
            }
            historyPageMap[currentWKItem] = anItem
        } else {
            // Update title and url
            if let title = currentWKItem.title, title != "" {
                tab.currentItem?.title = title
            }
            tab.currentItem?.url = currentWKItem.url
        }
        tab.currentItem = anItem
    }
    
    // Convenience to convert wkwebview history item
    func addPage(from item: WKBackForwardListItem, parent: HistoryItem?) -> HistoryItem? {
        return addPage(parent: parent, url: item.url, title: item.title)
    }
    
    func addPage(parent: HistoryItem?, url: URL, title: String?) -> HistoryItem? {

        let context = persistentContainer.viewContext
        
        let historyItem = HistoryItem(context: context)
        
        historyItem.firstVisit = Date()
        historyItem.uuid = UUID()
        historyItem.url = url
        historyItem.title = title ?? "Untitled"
        historyItem.backItem = parent
        
        // Save the context.
        do {
            try context.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nserror = error as NSError
            print("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        return historyItem
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}


