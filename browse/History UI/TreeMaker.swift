//
//  TreeMaker.swift
//  browse
//
//  Created by Evan Brooks on 4/20/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import CoreData

struct TreePosition: Hashable {
    let x: Int
    let y: Int
    
    var point: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

class TreeMaker : NSObject {
    private let initialMaxDepth = 10
    private let viewContext = HistoryManager.shared.persistentContainer.viewContext
    
    private var layout: TreeMakerLayout
    private var nodeIDs: [IndexPath : NSManagedObjectID] = [:]
    private var parentIDs: [IndexPath : NSManagedObjectID] = [:]
    private var cellPositions: [NSManagedObjectID : TreePosition] = [:]
    
    var _nodeCount: Int = 0
    var _gridSize: CGSize = .zero
    
    var nodeCount: Int {
        return _nodeCount
    }
    var gridSize: CGSize {
        return _gridSize
    }

    init(layout: TreeMakerLayout) {
        self.layout = layout
        super.init()
    }
    
    func indexPath(for visit: Visit) -> IndexPath? {
        return nodeIDs.first(where: { (ip, id) -> Bool in
            id == visit.objectID
        })?.key
    }
    
    func object(at ip: IndexPath) -> Visit? {
        guard let id = nodeIDs[ip] else {
            print("Unknown Indexpath: \(ip)")
            return nil
        }
        do {
            return try viewContext.existingObject(with: id) as? Visit
        }
        catch {
            print("Can't find visit on main thread: \(error.localizedDescription)")
            return nil
        }
    }
    
    func position(for ip: IndexPath) -> TreePosition? {
        guard let id = nodeIDs[ip] else { return nil }
        return cellPositions[id]
    }
    
    func parentPosition(for ip: IndexPath) -> TreePosition? {
        guard let parentID = parentIDs[ip] else { return nil }
        return cellPositions[parentID]
    }
    
    func addVisit(_ visit: Visit, at position: TreePosition) {
        let ip = IndexPath(item: nodeIDs.count, section: 0)
        nodeIDs[ip] = visit.objectID
        cellPositions[visit.objectID] = position
        
        if let backVisit = visit.backItem {
            parentIDs[ip] = backVisit.objectID
        }
    }
    
    private func openTabsFirst(_ a: Visit, _ b: Visit) -> Bool {
        let aClosed = a.tab?.isClosed ?? true
        let bClosed = b.tab?.isClosed ?? true
        if aClosed && bClosed { return oldToNew(a, b) }
        else if !aClosed && !bClosed { return oldToNew(a, b) }
        else if aClosed { return false }
        else if bClosed { return true }
        return false
    }

    private func oldToNew(_ a: Visit, _ b: Visit) -> Bool {
        guard let ad = a.date, let bd = b.date else { return false }
        return ad < bd
    }
    private func newToOld(_ a: Visit, _ b: Visit) -> Bool {
        guard let ad = a.date, let bd = b.date else { return false }
        return ad > bd
    }
    private func hasChildrenFirst(_ a: Visit, _ b: Visit) -> Bool {
        guard let ad = a.date, let bd = b.date else { return false }
        let ac = a.forwardItems?.count ?? 0
        let bc = b.forwardItems?.count ?? 0
        if ac == bc { return ad > bd }
        return ac > bc
    }

    private func traverseTrees(from roots: [Visit]) {
        var currentDepth: Int = 0
        var maxDepth: Int = 0
        var maxY: Int = 0
        
        var usedPositions = Set<TreePosition>()
        func availablePos(for potentialPos: TreePosition) -> TreePosition {
            var pos = potentialPos
            while usedPositions.contains(pos) {
                pos = TreePosition(x: potentialPos.x, y: pos.y + 1)
            }
            return pos
        }
        
        func traverse(_ node: Visit) {
            var currentY = 0
            if let back = node.backItem,
                let parentPos = cellPositions[back.objectID] {
                currentY = parentPos.y
            }
            let pos = availablePos(for: TreePosition(x: currentDepth, y: currentY))
            
            
            if pos.y > maxY { maxY = pos.y }
            usedPositions.insert(pos)
            self.addVisit(node, at: pos)
            
//            if currentDepth > initialMaxDepth { return }
            if let children = node.forwardItems?.allObjects as? [Visit] {
                currentDepth += 1
                if currentDepth > maxDepth { maxDepth = currentDepth }
                for child in children.sorted(by: hasChildrenFirst) {
                    traverse(child)
                }
                currentDepth -= 1
            }
        }
        roots.sorted(by: openTabsFirst).forEach {
            traverse($0)
        }
        
        self._gridSize = CGSize(width: maxDepth, height: maxY + 1)
        self._nodeCount = nodeIDs.count
    }
    
    private func traverseTreesAbsolute(from roots: [Visit]) {
        var currentY: Int = 0
        var currentDepth: Int = 0
        var maxDepth: Int = 0

        func traverse(_ node: Visit) {
            let subtreeStartY = currentY
            let pos = TreePosition(x: currentDepth, y: subtreeStartY)
            self.addVisit(node, at: pos)

            if let children = node.forwardItems?.allObjects as? [Visit] {
                currentDepth += 1
                if currentDepth > maxDepth { maxDepth = currentDepth }
                for child in children.sorted(by: newToOld) {
                    traverse(child)
                }
                currentDepth -= 1
            }
            if subtreeStartY == currentY {
                currentY += 1
            }
        }
        roots.sorted(by: openTabsFirst).forEach {
            traverse($0)
        }

        self._gridSize = CGSize(width: maxDepth, height: currentY)
        self._nodeCount = nodeIDs.count
    }
    
    func loadTabs() {
        HistoryManager.shared.persistentContainer.performBackgroundTask { ctx in
        }
    }
    
    // TODO: Do our own fetchrequest here so we can
    // also show closed tabs
    func loadTabs(selectedTab: Tab?, completion: (() -> ())?) {
        HistoryManager.shared.persistentContainer.performBackgroundTask { ctx in
            var tabs: [Tab]
            let request: NSFetchRequest<Tab> = Tab.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "creationTime", ascending: false),
            ]
            request.fetchBatchSize = 20
            do {
                tabs = try ctx.fetch(request)
            } catch let error{
                print(error)
                return
            }
            let rootTabs = tabs.filter({ tab -> Bool in
                // child tabs belong inline
                if let parent = tab.parentTab, tabs.contains(parent) {
                    return false
                }
                return true
            })

            let currentVisits: [Visit] = rootTabs.map { $0.currentVisit! }
            let currentRoots: [Visit] = currentVisits.map { visit in
                var root = visit
                var backDepth = 0
                while let backItem = root.backItem, backDepth < self.initialMaxDepth {
                    root = backItem
                    backDepth += 1
                }
                return root
            }
            
            self.traverseTrees(from: currentRoots)
            self.applyLayout(selectedTab: selectedTab, completion: completion)
        }
    }
    
    private func applyLayout(selectedTab: Tab?, completion: (() -> ())?) {
        DispatchQueue.main.async {
            self.layout.collectionView?.reloadData()
            self.layout.invalidateLayout()
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
}
