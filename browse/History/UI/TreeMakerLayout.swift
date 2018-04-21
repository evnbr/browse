//
//  TreeMakerLayout.swift
//  browse
//
//  Created by Evan Brooks on 04/14/18.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit


class TreeMakerLayout: UICollectionViewLayout {
    var attributesList = [ UICollectionViewLayoutAttributes ]()
    var spacing = CGPoint(x: 130, y: 220)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }
        guard let treeMaker = (cv.dataSource as? TreeDataSource)?.treeMaker else { return .zero }

        let size = treeMaker.gridSize
        return CGSize(
            width: size.width * spacing.x,
            height: size.height * spacing.y)
    }
    
    override init() {
        super.init()
    }
    
    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }
        guard let treeMaker = (cv.dataSource as? TreeDataSource)?.treeMaker else { return }

        let count = cv.numberOfItems(inSection: 0)
        
        attributesList = (0..<count).map { i -> UICollectionViewLayoutAttributes in
            let indexPath = IndexPath(item: i, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.bounds = CGRect(x: 0, y: 0, width: 240, height: 420)
            attributes.transform = CGAffineTransform(scale: 0.5)

            if let pt = treeMaker.position(for: indexPath)?.point {
                attributes.center = CGPoint(x: (0.5 + pt.x) * spacing.x, y: (0.5 + pt.y) * spacing.y)
            }
            
            return attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributesList.filter { attrs -> Bool in
            return rect.intersects(attrs.frame.insetBy(dx: -40, dy: -40))
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.count > 0, // sometimes this method sent nil paths - why?
            indexPath.row < attributesList.count else { return nil }
        return attributesList[indexPath.row]
    }
}
