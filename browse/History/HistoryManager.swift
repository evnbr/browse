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
    private var historyIDMap: [ WKBackForwardListItem : NSManagedObjectID ] = [:]

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HistoryModel")
        container.loadPersistentStores { (_, error) in
            if let error = error as NSError? {
                print("Unresolved error loading stores: \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(mergeChangeIntoMainContext(notif:)),
            name: .NSManagedObjectContextDidSave,
            object: nil)
    }
    
    @objc func mergeChangeIntoMainContext(notif: Notification) {
        // this wasn't running on main thread before and may have been crashing
        DispatchQueue.main.async {
            self.persistentContainer.viewContext.mergeChanges(fromContextDidSave: notif)
        }
    }
    
    func hasWKListItem(for visit: Visit) -> Bool {
        let id = visit.objectID
        return historyIDMap.contains(where: { (_, v) -> Bool in
            return v == id
        })
    }
    
    func wkListItem(for visit: Visit) -> WKBackForwardListItem? {
        let id = visit.objectID
        return historyIDMap.first(where: { (_, v) -> Bool in
            return v == id
        })?.key
    }

    func existingVisit(from item: WKBackForwardListItem, in context: NSManagedObjectContext) -> Visit? {
        guard let id = historyIDMap[item] else { return nil }
        do {
            return try context.existingObject(with: id) as? Visit
        } catch let error {
            print(error)
            return nil
        }
    }
    
    func existingSite(for url: URL, in context: NSManagedObjectContext) -> Site? {
        let request: NSFetchRequest<Site> = Site.fetchRequest()
        request.predicate = NSPredicate(format: "url == %@", url.absoluteString)
        request.fetchLimit = 1
        do {
            let results = try context.fetch(request)
            return results.first
        } catch let error {
            print(error)
            return nil
        }
    }
    
    var isSyncing = false
    func sync(tab mainThreadTab: Tab, with list: WKBackForwardList) {
        if isSyncing { return }
        guard let wkItem = list.currentItem else { return }
        
        if mainThreadTab.currentVisit?.objectID == historyIDMap[wkItem]
        && mainThreadTab.currentVisit?.url == wkItem.url
        && mainThreadTab.currentVisit?.title == wkItem.title {
            // unchanged, don't need to hit core data
            return
        }

        persistentContainer.performBackgroundTask { ctx in
            guard let obj = try? ctx.existingObject(with: mainThreadTab.objectID),
                let tab = obj as? Tab else {
                print("tab doesn't exist on bg context")
                return
            }
            self.isSyncing = true

            if let existingVisit = self.existingVisit(from: wkItem, in: ctx) {
                // Update title, url, and children
                if let title = wkItem.title, title != "" {
                    existingVisit.title = title
                }
                existingVisit.url = wkItem.url

                tab.currentVisit?.isCurrentVisitOf = nil
                tab.currentVisit = existingVisit
                existingVisit.isCurrentVisitOf = tab
            } else if list.backItem == nil && wkItem.url == tab.currentVisit?.url {
                // Restore session
                // TODO: This is redundant
                self.historyIDMap[wkItem] = tab.currentVisit?.objectID
            } else {
                // Create a new entry
                let newVisit = self.addVisit(from: wkItem, in: ctx)!

                if let backWKItem = list.backItem,
                    let backVisit = self.existingVisit(from: backWKItem, in: ctx),
                    backVisit == tab.currentVisit {
                    // We went forward, link these pages together
                    newVisit.backItem = tab.currentVisit
                    tab.currentVisit?.addToForwardItems(newVisit)
                }

                tab.currentVisit?.isCurrentVisitOf = nil
                tab.currentVisit = newVisit
                tab.addToVisits(newVisit)
                newVisit.isCurrentVisitOf = tab
                newVisit.tab = tab

                if let parentTabVisit = tab.parentTab?.currentVisit, list.backItem == nil {
                    // Opened in new tab, create cross-tab link
                    newVisit.backItem = parentTabVisit
                    parentTabVisit.addToForwardItems(newVisit)
                }
            }

            // Add or update canonical site
            let site = self.siteFor(tab: tab, item: wkItem, in: ctx)

            // Update canonical site
            if let visit = tab.currentVisit, let site = site {
                if let title = wkItem.title, title != "" {
                    site.title = title
                }
                if visit.site !== site {
                    let oldSite = visit.site
                    oldSite?.removeFromVisits(visit)
                    visit.site = site
                    site.addToVisits(visit)
                }
                if let count = site.visits?.count {
                    site.visitCount = Int32(count)
                }
            }

            self.save(context: ctx)
            self.historyIDMap[wkItem] = tab.currentVisit!.objectID // id is temp until saved
            self.isSyncing = false
        }
    }

    func siteFor(tab: Tab, item wkItem: WKBackForwardListItem, in ctx: NSManagedObjectContext) -> Site? {
        if let currentSite = tab.currentVisit?.site, currentSite.url == wkItem.url {
            return currentSite
        }
        if let existingSite = self.existingSite(for: wkItem.url, in: ctx) {
            return existingSite
        }
        if let newSite = self.addSite(url: wkItem.url, title: wkItem.title, in: ctx) {
            return newSite
        }
        print("couldn't create a new site")
        return nil
    }

    // Convert wkwebview history item
    func addVisit(from item: WKBackForwardListItem, in context: NSManagedObjectContext) -> Visit? {
        return addVisit(url: item.url, title: item.title, in: context)
    }

    // Convert and save history item
    func addVisit(url: URL, title: String?, in context: NSManagedObjectContext) -> Visit? {
        let visit = Visit(context: context)
        visit.date = Date()
        visit.uuid = UUID()
        visit.url = url
        visit.title = title ?? url.host ?? url.absoluteString
        return visit
    }

    func addSite(url: URL, title: String?, in context: NSManagedObjectContext) -> Site? {
        let site = Site(context: context)
        site.title = title ?? url.host ?? url.absoluteString
        site.url = url
        return site
    }

    func saveViewContext() {
        save(context: persistentContainer.viewContext)
    }

    func save(context: NSManagedObjectContext) {
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error saving: \(nserror.localizedDescription)")
                print("\(nserror.userInfo)")
            }
        }
    }
}

// Convenience to get Visit from webview
extension WKBackForwardListItem {
    var visit: Visit? {
        // TODO: This is an expensive operation
        // to do on the main thread.
        let ctx = HistoryManager.shared.persistentContainer.viewContext
        let existVisit = HistoryManager.shared.existingVisit(from: self, in: ctx)
        return existVisit
    }
}

// Typeahead fetching
extension HistoryManager {
    private func fetchItemsContaining(_ str: String, completion: @escaping ([HistorySearchResult]?) -> Void ) {
        guard str.count > 0 else {
            completion(nil)
            return
        }
        persistentContainer.performBackgroundTask { ctx in
            let request: NSFetchRequest<Site> = Site.fetchRequest()

            // todo: doesn't handle spaces
            var predicates: [NSPredicate] = []
            for word in str.split(separator: " ") {
                if word.count < 2 {
                    predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "url CONTAINS[cd] %@", ".\(word)*."), // www.WOrd.com
                        NSPredicate(format: "url CONTAINS[cd] %@", "//\(word)"), // prot://WOrd.com
                        NSPredicate(format: "title BEGINSWITH[cd] %@", "\(word)") // WOrd
                    ]))
                } else {
                    predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "url CONTAINS[cd] %@", ".\(word)"), // www.WOrd.com
                        NSPredicate(format: "url CONTAINS[cd] %@", "/\(word)"), // prot://WOrd.com
                        NSPredicate(format: "title CONTAINS[cd] %@", " \(word)") // The_WOrd
                    ]))
                }
            }
            if predicates.count < 1 {
                completion(nil)
                return
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [ NSSortDescriptor(key: "visitCount", ascending: false) ]

            request.propertiesToFetch = ["url", "title", "visitCount"]
            request.returnsDistinctResults = true

            // Should be enough to filter more carefully later
            request.returnsObjectsAsFaults = false
            request.fetchBatchSize = 12
            request.fetchLimit = 12
            do {
                let results = try ctx.fetch(request)
                var cleanResults : [ HistorySearchResult ] = []
                for result in results {
                    if let title = result.title, let url = result.url {
                        cleanResults.append(HistorySearchResult(
                            title: title,
                            url: url,
                            visitCount: Int(result.visitCount)
                        ))
                    }
                }
                completion(cleanResults)
            } catch let error {
                completion(nil)
                print(error)
            }
        }
    }

    func findItemsMatching(_ str: String, completion: @escaping ([HistorySearchResult]?) -> Void ) {
        fetchItemsContaining(str) { completion($0) }
    }
}

struct HistorySearchResult {
    let title: String
    let url: URL
    let visitCount: Int
}

// Deal with snapshots
extension HistoryManager {
    func snapshot(for id: UUID) -> UIImage? {
        if let cached = snapshotCache[id] { return cached }
        return loadSnapshotFromFile(id)
    }

    func setSnapshot(_ image: UIImage, for item: Visit) {
        guard let uuid = item.uuid else {
            print("set item has no uuid: \(item)")
            return
        }
        snapshotCache[uuid] = image

        // TODO: Only do this on save, otherwise wastefully overwriting all the time
        writeSnapshotToFile(image, id: uuid)
    }

    func loadSnapshotFromFile(_ uuid: UUID) -> UIImage? {
        guard let dir = FileManager.defaultDirURL else { return nil }
        let image = UIImage(contentsOfFile:
            URL(fileURLWithPath: dir.absoluteString).appendingPathComponent("\(uuid.uuidString).png").path)
        snapshotCache[uuid] = image
        return image
    }

    func writeSnapshotToFile(_ image: UIImage, id: UUID) {
        DispatchQueue.global(qos: .userInitiated).async {
            let size = image.size.applying(CGAffineTransform(scale: 0.5))
            UIGraphicsBeginImageContextWithOptions(size, true, 1)
            image.draw(in: CGRect(origin: .zero, size: size))
            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            guard let img = scaledImage,
                let data = UIImagePNGRepresentation(img),
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
    static var defaultDirURL: URL? {
        return try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false)
    }
}
