//
//  BlobCollectionViewLayout.swift
//  browse
//
//  Created by Evan Brooks on 3/9/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit


let margin : CGFloat = 8
let baseHeight : CGFloat = 320

class BlobCollectionViewLayout: UICollectionViewFlowLayout {
    var attributesList = [UICollectionViewLayoutAttributes]()
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: collectionView!.bounds.width,
                      height: 200 + CGFloat(collectionView!.numberOfItems(inSection: 0)) * baseHeight)
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
//    override func prepare() {
//        super.prepare()
//
//        let topScrollPos = Const.statusHeight + 12 //60
//        let scrollPos = collectionView!.contentOffset.y
//
//        let count = collectionView!.numberOfItems(inSection: 0)
//
//        let cardSize = UIScreen.main.bounds.size
//
//        var lastY : CGFloat = 120
//        var lastH : CGFloat = 0
//
//        let inset : CGFloat = 8
//        var baseHeight : CGFloat = 320
//
//        attributesList = (0..<count).map { (i)
//            -> UICollectionViewLayoutAttributes in
//            // 1
//            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
//
//            var origin = CGPoint(
//                x: inset,
//                y: lastY + lastH + 8
//            )
//            let distFromTop = origin.y - scrollPos
//            let pctFromTop = distFromTop.progress(from: 0, to: 400).clip()
//
//            let distFromBottom = cardSize.height - distFromTop
//            let pctFromBottom = distFromBottom.progress(from: 0, to: 400).clip()
//
//            let newSize = CGSize(width: cardSize.width - inset * 2, height: baseHeight * pctFromTop * pctFromBottom)
//
//            lastH = newSize.height
//            lastY = origin.y
//
//            attributes.frame = CGRect(origin: origin, size: newSize)
//
//            return attributes
//        }
//    }
    override func prepare() {
        super.prepare()
        
        let cv = collectionView!
        let scrollPos = cv.contentOffset.y
        
        let count = cv.numberOfItems(inSection: 0)
        
        let cardSize = UIScreen.main.bounds.size
        
        
        let centerYs = (0..<count).map { i -> CGFloat in
            return cv.center.y + CGFloat(i) * (baseHeight + margin)
        }
        let pctFromCenter = centerYs.map { y -> CGFloat in
            let distFromCenter = y - scrollPos - cv.center.y
            let pct = distFromCenter.progress(from: 0, to: 600)
            return (pct * abs(pct) * 1.2).limit(min: -1, max: 1) * 0.95
        }
        let heights = pctFromCenter.map { pct -> CGFloat in
            let shrinkBy = baseHeight * abs(pct)
            return baseHeight - shrinkBy
        }
        let switchIndex = pctFromCenter.index(where: { $0 > 0 }) ?? count
        let adjustedYs = (0..<count).map { i -> CGFloat in
            var adjustY : CGFloat = 0
            
            adjustY += pctFromCenter[i] * baseHeight * 0.5
            
            if i < switchIndex {
                for index in i..<switchIndex {
                    let shift = baseHeight - heights[index]
                    adjustY += shift
                }
            }
            else {
                for index in switchIndex...i {
                    let shift = baseHeight - heights[index]
                    adjustY -= shift
                }
            }
            return centerYs[i] + adjustY
        }

        attributesList = (0..<count).map { i -> UICollectionViewLayoutAttributes in
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            
            let size = CGSize(width: cardSize.width, height: heights[i])
            attributes.center = CGPoint(x: cv.center.x, y: adjustedYs[i])
            attributes.bounds = CGRect(origin: .zero, size: size)
//            attributes.alpha = 1 - abs(pctFromCenter[i]) * 0.5
            return attributes
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let limit = (collectionView!.bounds.width - THUMB_INSET * 2) * 0.85
        return attributesList.filter({ attr -> Bool in
            return attr.alpha > 0.1
        })
        //        return super.layoutAttributesForElements(in: rect)
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return attributesList[indexPath.row]
        //        return super.layoutAttributesForItem(at: indexPath)
    }
}
