//
//  StackingCollectionViewLayout.swift
//  browse
//
//  Created by Evan Brooks on 10/5/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

let itemSpacing : CGFloat = 160
let itemHeight : CGFloat = THUMB_H

// TODO: drive this progress
// with POP as described in
// http://www.nicnocquee.com/ios/2015/01/29/drive-uicollectionview-interactive-layout-transition-using-facebooks-pop.html

class StackingTransition: UICollectionViewTransitionLayout {
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        // Only adjust scroll for user, "proposed" seems to be garbage?
//        print("current: \(collectionView!.contentOffset.y), proposed: \(proposedContentOffset.y)")
        return collectionView!.contentOffset
    }
}

class StackingCollectionViewLayout: UICollectionViewFlowLayout {
    
    private var isStacked: Bool = true
    var offset: CGPoint = .zero
    var scale: CGFloat = 1
    
    var selectedIndexPath = IndexPath(item: 0, section: 0)
    var selectedHidden: Bool = false
    var parentIndexPath: IndexPath? = nil
    var parentHidden: Bool = false
    
    var attributesList = [ UICollectionViewLayoutAttributes ]()
    
    init(isStacked : Bool) {
        super.init()
        self.isStacked = isStacked
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        let newSize = CGSize(
            width: collectionView!.bounds.width,
            height: CGFloat(collectionView!.numberOfItems(inSection: 0)) * itemSpacing + (itemHeight - itemSpacing) + 240)
//        print("ScrollPos: \(collectionView!.contentOffset.y)   H: \(newSize.height)")
        return newSize
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        // Only adjust scroll for user, "proposed" seems to be garbage?
//        print("current: \(collectionView!.contentOffset.y), proposed: \(proposedContentOffset.y)")
        return collectionView!.contentOffset
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if newBounds == collectionView?.bounds { return false }
//        print("did scroll")
        return true
    }
    
    override func invalidateLayout() {
//        print("invalidated")
        super.invalidateLayout()
    }
    
    override func prepare() {
        super.prepare()
//        print("prepare - isStacked: \(isStacked)")

        attributesList = calculateList(stacked: isStacked)
    }
    
    private func calculateList(stacked: Bool) -> [UICollectionViewLayoutAttributes] {
        let count = collectionView!.numberOfItems(inSection: 0)
        let attributesList = (0..<count).map { i -> UICollectionViewLayoutAttributes in
            let indexPath = IndexPath(item: i, section: 0)
            return calculateItem(for: indexPath, whenStacked: stacked)
        }
        return attributesList
    }
    
    private var itemCount: Int {
        return collectionView!.numberOfItems(inSection: 0)
    }
        
    private func calculateItem(for indexPath: IndexPath, whenStacked: Bool) -> UICollectionViewLayoutAttributes {
        let topScrollPos = Const.statusHeight + 12 //60
        let scrollPos = collectionView!.contentOffset.y
        
        let cardSize = UIScreen.main.bounds.size
        
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let i = indexPath.item
        let distFromFront : CGFloat = CGFloat(selectedIndexPath.item - i)
        
        var newCenter = CGPoint(
            x: collectionView!.center.x,
            y: 240.0 + collectionView!.center.y + CGFloat(i) * itemSpacing
        )
        
        attributes.bounds.size = cardSize
        
        if cardSize.width > cardSize.height {
            let pct = (attributes.bounds.width - 96) / attributes.bounds.width
            attributes.bounds.size.width *= pct
            attributes.bounds.size.height *= pct
        }
        
        let distFromTop = newCenter.y - (attributes.bounds.height / 2) - scrollPos - topScrollPos
        
        let pct = distFromTop.progress(from: -400, to: 600).reverse()
//        let s = (pct * pct * 0.1).reverse()
//            attributes.transform = CGAffineTransform(scaleX: s, y: s)
        
        attributes.isHidden = false
        if whenStacked {
            newCenter.y -= distFromTop * 0.95 * pct
            attributes.transform = .identity //CGAffineTransform(scale: s)
        } else {
            if indexPath != selectedIndexPath {
                let endCenter = calculateItem(for: selectedIndexPath, whenStacked: true).center
                let endDistFromTop = endCenter.y - scrollPos - cardSize.height / 2
                newCenter.y = endCenter.y - (cardSize.height * (scale) + 12) * distFromFront - endDistFromTop
            }
            
            attributes.transform = CGAffineTransform(scale: scale)
            newCenter.x -= offset.x
            newCenter.y -= offset.y
            if parentHidden && indexPath == parentIndexPath {
                attributes.isHidden = true
            }
        }
        if selectedHidden && indexPath == selectedIndexPath {
            attributes.isHidden = true
        }
        
        if i < itemCount - 1 {
            attributes.alpha = 1 - ( pct * pct * pct )
            // attributes.transform = CGAffineTransform(scale: s)
        }
        
        attributes.center = newCenter
        attributes.zIndex = i * 20
        
        return attributes
    }

    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributesList
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return attributesList[indexPath.row]
    }
}
