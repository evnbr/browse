//
//  TabStackingLayout.swift
//  browse
//
//  Created by Evan Brooks on 10/5/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

let itemSpacing : CGFloat = 200
let itemHeight : CGFloat = THUMB_H
let startY : CGFloat = 240

class CardStackingLayout: UICollectionViewFlowLayout {
    
    var offset: CGPoint = .zero
    var maxScale: CGFloat = 1
    
    var selectedIndexPath = IndexPath(item: 0, section: 0)
    var selectedHidden: Bool = false
    var belowHidden: Bool = false
    var parentIndexPath: IndexPath? = nil
    var parentHidden: Bool = false
    
    var stackedAttributes = [ UICollectionViewLayoutAttributes ]()
    var expandedAttributes = [ UICollectionViewLayoutAttributes ]()
    var blendedAttributes = [ UICollectionViewLayoutAttributes ]()
    
    var expandedProgress: CGFloat = 0
    var dismissProgress: CGFloat = 0
    var dismissIndexPath: IndexPath? = nil

    override var collectionViewContentSize: CGSize {
        var newSize = CGSize(
            width: collectionView!.bounds.width,
            height: startY + CGFloat(collectionView!.numberOfItems(inSection: 0)) * itemSpacing + (itemHeight - itemSpacing))
//        newSize.height -= dismissProgress * itemSpacing
        return newSize
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        // Only adjust scroll for user, "proposed" seems to be garbage?
        if let cv = collectionView, collectionViewContentSize.height <= cv.bounds.size.height {
//            print("contentsize too small")
//            return proposedContentOffset
        }
        
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

        stackedAttributes = calculateList(stacked: true)
        expandedAttributes = calculateList(stacked: false)
        blendedAttributes = (0..<itemCount).map { i -> UICollectionViewLayoutAttributes in
            let attrs = stackedAttributes[i]
            let expandedAttrs = expandedAttributes[i]
            let stackCenter = attrs.center
            let stackScale = attrs.scale
            attrs.center = expandedProgress.lerp(stackCenter, expandedAttrs.center)
            attrs.scale = expandedProgress.lerp(stackScale, maxScale)
            attrs.isHidden = attrs.isHidden || expandedAttrs.isHidden
            return attrs
        }
    }
    
    private var itemCount: Int {
        return collectionView!.numberOfItems(inSection: 0)
    }
    
    private func calculateList(stacked: Bool) -> [UICollectionViewLayoutAttributes] {
        let baseCenter = collectionView!.center
        let scrollY = collectionView!.contentOffset.y
        let attributesList = (0..<itemCount).map { i -> UICollectionViewLayoutAttributes in
            let indexPath = IndexPath(item: i, section: 0)
            return calculateItem(
                for: indexPath,
                whenStacked: stacked,
                scrollY: scrollY,
                baseCenter: baseCenter,
                totalItems: itemCount)
        }
        return attributesList
    }
    
    func calculateItem(for indexPath: IndexPath, whenStacked: Bool, scrollY: CGFloat, baseCenter: CGPoint, totalItems: Int, withOffset: Bool = true) -> UICollectionViewLayoutAttributes {
        let topScrollPos = Const.statusHeight + 60
        let cardSize = UIScreen.main.bounds.size

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let i = indexPath.item
        let distFromFront : CGFloat = CGFloat(selectedIndexPath.item - i)
        
        var newCenter = CGPoint(
            x: baseCenter.x,
            y: startY + baseCenter.y + CGFloat(i) * itemSpacing
        )
        if let dip = dismissIndexPath {
            if indexPath.row == dip.row {
                newCenter.x += collectionView!.bounds.width * dismissProgress
            }
            if indexPath.row > dip.row {
                newCenter.y -= itemSpacing * dismissProgress * 0.5
            }
            else if indexPath.row < dip.row {
                newCenter.y += itemSpacing * dismissProgress * 0.5
            }
        }
        
        attributes.bounds.size = cardSize
        
        if cardSize.width > cardSize.height {
            let pct = (attributes.bounds.width - 96) / attributes.bounds.width
            attributes.bounds.size.width *= pct
            attributes.bounds.size.height *= pct
        }
        
        let distFromTop = newCenter.y - (attributes.bounds.height / 2) - scrollY - topScrollPos
        
        let pct = distFromTop.progress(-400, 600).reverse()
        let s = (pct * pct * 0.2).reverse()
        
        let extraH = cardSize.height * (1 - s)
        
        attributes.isHidden = false
        if whenStacked {
            newCenter.y -= extraH //* 0.5
            newCenter.y -= distFromTop * 1 * pct
            attributes.transform = CGAffineTransform(scale: s * maxScale)
        } else {
            if indexPath != selectedIndexPath {
                let endCenter = calculateItem(for: selectedIndexPath, whenStacked: true, scrollY: scrollY, baseCenter: baseCenter, totalItems: totalItems, withOffset: false).center
                let endDistFromTop = endCenter.y - scrollY - cardSize.height / 2
                newCenter.y = endCenter.y - (cardSize.height * (maxScale) + 12) * distFromFront - endDistFromTop
            }
            
            attributes.transform = CGAffineTransform(scale: maxScale)
            if parentHidden && indexPath == parentIndexPath {
                attributes.isHidden = true
            }
            newCenter.y -= offset.y
        }
        if withOffset {
            newCenter.x -= offset.x
        }

        if selectedHidden && indexPath == selectedIndexPath {
            attributes.isHidden = true
        }
        if belowHidden && indexPath.row > selectedIndexPath.row {
            attributes.isHidden = true
        }
        
        if i < totalItems - 1 {
            attributes.alpha = 1 - ( pct * pct * pct )
            // attributes.transform = CGAffineTransform(scale: s)
        }
        if i == totalItems - 1 {
            attributes.alpha = 1
            attributes.transform = .identity
        }
        
        attributes.center = newCenter
        attributes.zIndex = i * 2
        
        return attributes
    }

    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attrs = blendedAttributes.filter { attrs -> Bool in
            return rect.intersects(attrs.frame.insetBy(dx: -40, dy: -40)) && attrs.alpha > 0 && !attrs.isHidden
        }
        return attrs
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.count > 0, // sometimes this method sent nil paths - why?
            indexPath.row < blendedAttributes.count else { return nil }
        return blendedAttributes[indexPath.row]
    }
}
