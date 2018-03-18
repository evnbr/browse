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
    
    private var snapshotCache: [ UUID : UIImage ] = [:]
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
        if let cachedItem = page(from: currentWKItem) {
            // Update title and url
            if let title = currentWKItem.title, title != "" {
                cachedItem.title = title
            }
            cachedItem.url = currentWKItem.url
            tab.currentItem = cachedItem
        }
        else {
            // Create a new entry
            let newItem = addPage(from: currentWKItem, parent: nil)
            if let backWKItem = list.backItem,
                let backItem = page(from: backWKItem),
                backItem == tab.currentItem {
                // We went forward, link these pages together
                newItem?.backItem = tab.currentItem
                tab.currentItem?.addToForwardItems(newItem!)
            }
            historyPageMap[currentWKItem] = newItem
            tab.currentItem = newItem
        }
        saveContext()
    }
    
    // Convert wkwebview history item
    func addPage(from item: WKBackForwardListItem, parent: HistoryItem?) -> HistoryItem? {
        return addPage(parent: parent, url: item.url, title: item.title)
    }
    
    // Convert and save history item
    func addPage(parent: HistoryItem?, url: URL, title: String?) -> HistoryItem? {
        let context = persistentContainer.viewContext
        
        let historyItem = HistoryItem(context: context)
        historyItem.firstVisit = Date()
        historyItem.uuid = UUID()
        historyItem.url = url
        historyItem.title = title ?? "Untitled"
        historyItem.backItem = parent
        return historyItem
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

// Deal with snapshots
extension HistoryManager {
    func snapshot(for item: HistoryItem) -> UIImage? {
        guard let id = item.uuid else { return nil }
        if let cached = snapshotCache[id] { return cached }
        return loadSnapshotFromFile(id)
    }
    
    func setSnapshot(_ image: UIImage, for item: HistoryItem) {
        guard let uuid = item.uuid else { return }
        snapshotCache[uuid] = image
        writeSnapshotToFile(image, id: uuid)
    }
    
    func loadSnapshotFromFile(_ id: UUID) -> UIImage? {
        guard let dir = FileManager.defaultDirURL else { return nil }
        return UIImage(contentsOfFile:
            URL(fileURLWithPath: dir.absoluteString).appendingPathComponent("\(id.uuidString).png").path)
    }
    
    func writeSnapshotToFile(_ image: UIImage, id: UUID) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = UIImagePNGRepresentation(image),
                let dir = FileManager.defaultDirURL
                else { return }
            do {
                try data.write(to: dir.appendingPathComponent("\(id.uuidString).png"))
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}


fileprivate extension FileManager {
    static var defaultDirURL : URL? {
        return try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
}
