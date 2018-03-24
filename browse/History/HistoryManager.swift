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

// Convenience to get HistoryItem from webview
extension WKBackForwardListItem {
    var model : HistoryItem? {
        return HistoryManager.shared.page(from: self)
    }
}

// Fetch
extension HistoryManager {
    private func fetchItemsContaining(_ str: String, completion: @escaping ([HistorySearchResult]?) -> () ) {
        guard str.count > 0 else { return }
        persistentContainer.performBackgroundTask { ctx in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "HistoryItem")
            
            // todo: doesn't handle spaces
            var predicates : [NSPredicate] = []
            for word in str.split(separator: " ") {
                if word != "" {
                    predicates.append(NSPredicate(format: "url CONTAINS[cd] %@", ".\(word)")) // www.WOrd.com
                    predicates.append(NSPredicate(format: "url CONTAINS[cd] %@", "/\(word)")) // prot://WOrd.com
                    predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", " \(word)")) // The WOrd
                }
            }
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [ NSSortDescriptor(key: "firstVisit", ascending: true) ]
            
            // Distinct on URL or Title else full of dupes
            request.propertiesToFetch = ["url", "title"]
            request.returnsDistinctResults = true
            request.resultType = .dictionaryResultType

            // Should be enough to filter more carefully later
            request.returnsObjectsAsFaults = false
            request.fetchBatchSize = 20
            request.fetchLimit = 20
            do {
                let results = try ctx.fetch(request)
                var cleanResults : [ HistorySearchResult ] = []
                for result in results {
                    if let dict = result as? NSDictionary,
                        let title = dict["title"] as? String,
                        let url = dict["url"] as? URL {
                        cleanResults.append(HistorySearchResult(title: title, url: url))
                    }
                }
                completion(cleanResults)
            } catch let error{
                completion(nil)
                print(error)
            }
        }
    }
    
    func matchingScore(item: HistorySearchResult, text: String) -> Int {
        let inOrderScore = componentScore(item: item, text: text)
        
        // Split on spaces and sum scores
        let splitScore = text.split(separator: " ")
            .map { componentScore(item: item, text: String($0)) }
            .reduce(0, { $0 + $1 })
        return inOrderScore * 2 + splitScore
    }
    
    func matchesStrictly(item: HistorySearchResult, text: String) -> Bool {
        for word in text.split(separator: " ") {
            if word.count > 0
                && !item.title.localizedCaseInsensitiveContains(word)
                && !(item.url.host?.localizedCaseInsensitiveContains(word) ?? false) {
                return false
            }
        }
        return true
    }
    
    func componentScore(item: HistorySearchResult, text: String) -> Int {
        if text == "" { return 0 }
        var score : Float = 0
        
        // Points for words in the title
        if item.title.localizedCaseInsensitiveContains(text) {
            let words = item.title.split(separator: " ")
            let maxWordScore : Float = Float(words.count) / 200
            
            words.forEach { word in
                
                if word.starts(with: text) {
                    // 100 points per word starting with text
                    let pct : Float = Float(text.count) / Float(word.count)
                    score += maxWordScore * pct
                }
                else {
                    // 20 points if its elsewhere
                    let pct : Float = Float(text.count) / Float(word.count)
                    score += maxWordScore * pct * 0.2
                }
            }
        }
        
        // Points for host matching
        if let host = item.url.host, host.localizedCaseInsensitiveContains(text) {
            let parts = host.split(separator: ".")
            parts.forEach { part in
                if part.starts(with: text) {
                    // 100 points per host component starting with text
                    let pct : Float = Float(text.count) / Float(part.count)
                    score += 200 * pct
                }
                else {
                    // 20 points if its elsewhere
                    let pct : Float = Float(text.count) / Float(part.count)
                    score += 60 * pct
                }
            }
        }
        
        return Int(score)
    }
    
    func findItemsMatching(_ str: String, completion: @escaping ([HistorySearchResult]?) -> () ) {
        fetchItemsContaining(str) { poorlySorted in
            DispatchQueue.global(qos: .userInitiated).async {
                let nicelySorted = poorlySorted?
                    .filter { self.matchesStrictly(item: $0, text: str) }
                    .sorted(by: { (a, b) -> Bool in
                    self.matchingScore(item: a, text: str) > self.matchingScore(item: b, text: str)
                })
                completion(nicelySorted)
            }
        }
    }
}

struct HistorySearchResult {
    let title: String
    let url: URL
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
