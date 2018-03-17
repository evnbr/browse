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
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HistoryModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    // Convenience to convert wkwebview history item
    func addPage(from item: WKBackForwardListItem, parent: HistoryItem?) -> HistoryItem? {
        return addPage(parent: parent, url: item.url, title: item.title)
    }
    
    func addPage(parent: HistoryItem?, url: URL, title: String?) -> HistoryItem? {

        let context = persistentContainer.viewContext
        
        let historyItem = HistoryItem(context: context)
        
        historyItem.firstVisit = Date()
        historyItem.uuid = UUID()
        historyItem.url = url.absoluteString
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
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

// MARK: - Snapshots

// TODO: This reads and writes to filesystem on every change.
// Investigate whether its better to store some/all UIImages in memory,
// and/or whether its better to store images in coredata instead of file
extension HistoryItem {
    var snapshot: UIImage? {
        get {
            guard let uuid = self.uuid else { return nil }
            if let cached = HistoryManager.shared.snapshotCache[uuid] {
                return cached
            }
            guard let dir = FileManager.defaultDirURL else { return nil }
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent("\(uuid.uuidString).png").path)
        }
        set {
            guard let image = newValue, let uuid = self.uuid else { return }
            HistoryManager.shared.snapshotCache[uuid] = image

            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = UIImagePNGRepresentation(image), let dir = FileManager.defaultDirURL else { return }
                do {
                    try data.write(to: dir.appendingPathComponent("\(uuid.uuidString).png"))
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}

fileprivate extension FileManager {
    static var defaultDirURL : URL? {
        return try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
}
