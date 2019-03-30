//
//  TabStackingLayout.swift
//  browse
//
//  Created by Evan Brooks on 10/5/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

let itemSpacing: CGFloat = 200
let itemHeight: CGFloat = THUMB_H
let startY: CGFloat = 240

class CardStackCollectionViewLayout: UICollectionViewFlowLayout {
    
    var offset: CGPoint = .zero
    var maxScale: CGFloat = 1
    
    var selectedIndexPath = IndexPath(item: 0, section: 0)
    var selectedHidden: Bool = false
    var belowHidden: Bool = false
    var parentIndexPath: IndexPath?
    var parentHidden: Bool = false

    var stackedAttributes = [ UICollectionViewLayoutAttributes ]()
    var expandedAttributes = [ UICollectionViewLayoutAttributes ]()
    var blendedAttributes = [ UICollectionViewLayoutAttributes ]()

    var isTransitioning: Bool = false
    var expandedProgress: CGFloat = 0

    var swipeOffset: CGFloat = 0 // -1 to 1
    var dismissProgress: CGFloat = 0
    var dismissIndexPath: IndexPath?
    var addIndexPath: IndexPath?

    override var collectionViewContentSize: CGSize {
        var newSize = CGSize(
            width: collectionView!.bounds.width,
            height: startY + CGFloat(itemCount) * itemSpacing + (itemHeight - itemSpacing))
        newSize.height -= dismissProgress * itemSpacing
        return newSize
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        // Only adjust scroll for user, "proposed" seems to be garbage?
        if let cv = collectionView,
            collectionViewContentSize.height <= cv.bounds.size.height {
//            print("contentsize too small")
//            return proposedContentOffset
        }
        
        return collectionView!.contentOffset
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if newBounds == collectionView?.bounds { return false }
        return true
    }

    override func invalidateLayout() {
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
                baseScale: maxScale,
                totalItems: itemCount)
        }
        return attributesList
    }

    func selectedCenter(scrollY: CGFloat, baseCenter: CGPoint, totalItems: Int) -> CGPoint {
        return calculateItem(
            for: selectedIndexPath,
            whenStacked: true,
            scrollY: scrollY,
            baseCenter: baseCenter,
            baseScale: maxScale,
            totalItems: totalItems,
            withXOffset: false,
            withYOffset: false
        ).center
    }

    func stackOffsetY(baseCenter: CGPoint, endCenter: CGPoint, scrollY: CGFloat) -> CGFloat {
        let effectiveOffset = (baseCenter.y - endCenter.y)
        let scrollAdjust = scrollY // why is N necessary here?
        let newOffset = offset.y - effectiveOffset - scrollAdjust
        return newOffset
    }

    func calculateItem(
        for indexPath: IndexPath,
        whenStacked: Bool,
        scrollY: CGFloat,
        baseCenter: CGPoint,
        baseScale: CGFloat,
        totalItems: Int,
        withXOffset: Bool = true,
        withYOffset: Bool = true
    ) -> UICollectionViewLayoutAttributes {
        let topScrollPos = Const.statusHeight + 60
        let cardSize = UIScreen.main.bounds.size

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let i = indexPath.item
        let distFromFront: CGFloat = CGFloat(selectedIndexPath.item - i)

        var newCenter = CGPoint(
            x: baseCenter.x,
            y: startY + baseCenter.y + CGFloat(i) * itemSpacing
        )
        if let dip = dismissIndexPath {
            if indexPath.row == dip.row {
                newCenter.x += collectionView!.bounds.width * swipeOffset
            }
            if indexPath.row > dip.row {
                newCenter.y -= itemSpacing * dismissProgress //* 0.5
            }
//            else if indexPath.row < dip.row {
//                newCenter.y += itemSpacing * dismissProgress * 0.5
//            }
        }

        attributes.bounds.size = cardSize

        if cardSize.width > cardSize.height {
            let pct = (attributes.bounds.width - 96) / attributes.bounds.width
            attributes.bounds.size.width *= pct
            attributes.bounds.size.height *= pct
        }

        let distFromTop = newCenter.y - (attributes.bounds.height / 2) - scrollY - topScrollPos

        let pct = distFromTop.progress(-400, 600).reverse()
        let perspectiveScale = (pct * pct * 0.3).reverse() * 0.93

        let extraH = cardSize.height * (1 - perspectiveScale)

        let endCenter = withYOffset
            ? selectedCenter(scrollY: scrollY, baseCenter: baseCenter, totalItems: totalItems)
            : .zero

        let withYOffsetAndTransitioning = withYOffset && isTransitioning
        attributes.isHidden = false
        if whenStacked {
            newCenter.y -= extraH * 0.7
            newCenter.y -= distFromTop * pct
            if withYOffsetAndTransitioning {
                newCenter.y -= stackOffsetY(baseCenter: baseCenter, endCenter: endCenter, scrollY: scrollY)
            }
//            attributes.transform = CGAffineTransform(scale: perspectiveScale * baseScale)
        } else {
            if indexPath != selectedIndexPath {
                let endDistFromTop = endCenter.y - scrollY - cardSize.height / 2
                newCenter.y = endCenter.y - (cardSize.height * (baseScale) + 12) * distFromFront - endDistFromTop
            }

            attributes.transform = CGAffineTransform(scale: baseScale)
            if parentHidden && indexPath == parentIndexPath {
                attributes.isHidden = true
            }
            newCenter.y -= offset.y
        }
        if withXOffset {
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
        attributes.center = newCenter
        attributes.zIndex = i * 2
        return attributes
    }

    // Based on https://stackoverflow.com/questions/13498052/initiallayoutattributesforappearingitematindexpath-fired-for-all-visible-cells
    var deleteIndexPaths: [ IndexPath ] = []
    var insertIndexPaths: [ IndexPath ] = []
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        deleteIndexPaths = []
        insertIndexPaths = []
        for item in updateItems {
            if item.updateAction == .insert,
                let ip = item.indexPathAfterUpdate {
                insertIndexPaths.append(ip)
            } else if item.updateAction == .delete,
                let ip = item.indexPathBeforeUpdate {
                deleteIndexPaths.append(ip)
            }
        }
    }
    override func finalizeCollectionViewUpdates() {
        deleteIndexPaths = []
        insertIndexPaths = []
    }

    override func initialLayoutAttributesForAppearingItem(
        at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if insertIndexPaths.contains(itemIndexPath) {
            return exitPositionForItem(at: itemIndexPath)
        } else { return nil }
    }
//
//    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
//        return nil
//    }

    private func exitPositionForItem(at ip: IndexPath) -> UICollectionViewLayoutAttributes {
        let scrollY = collectionView!.contentOffset.y
        let baseCenter = collectionView!.center
        let attrs = calculateItem(for: ip, whenStacked: true, scrollY: scrollY, baseCenter: baseCenter, baseScale: maxScale, totalItems: itemCount)
        let cardSize = UIScreen.main.bounds.size
        attrs.bounds.size = cardSize
        attrs.center.y += cardSize.height
        attrs.zIndex = ip.item * 2
        return attrs
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
