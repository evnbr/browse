//
//  ColorBarCollectionViewController.swift
//  browse
//
//  Created by Evan Brooks on 1/25/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class ColorBarCollectionViewController: UICollectionViewController {

    let blur = PlainBlurView(frame: .zero)
    
    init() {
        super.init(collectionViewLayout: layout)
    }
    
    let layout = UICollectionViewFlowLayout()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let sliceHeight: CGFloat = 8
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false

        // Register cell classes
        collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        let size = UIScreen.main.bounds
        layout.itemSize = CGSize(width: size.width, height: sliceHeight)
        
//        view.addSubview(blur)
//        blur.frame = view.bounds
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    var contentHeight: CGFloat = 0
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(contentHeight / sliceHeight)
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
    
        // Configure the cell
        cell.backgroundColor = findClosestSample(indexPath.item)
        
        return cell
    }
    
    let topExtra: CGFloat = 300
    
    func update(_ scrollView: UIScrollView) {
        collectionView?.contentOffset.y = scrollView.contentOffset.y + topExtra
        let newHeight = scrollView.contentSize.height
        if newHeight != contentHeight {
            contentHeight = newHeight
            collectionView?.reloadData()
        }
    }
    
    var sampleCache: [Int: UIColor] = [:]
    func addSample(_ color: UIColor, offsetY: CGFloat) {
        let index = Int((offsetY + topExtra) / sliceHeight)
        sampleCache[index] = color
    }
    func findClosestSample(_ index: Int) -> UIColor {
        let closestIndex = sampleCache.keys.sorted{ abs($0 - index) < abs($1 - index) }.first
        if let index = closestIndex {
            return sampleCache[index] ?? UIColor.white
        }
        return UIColor.white
    }
    
    func averageColor() -> UIColor {
        let colors = collectionView!.visibleCells.compactMap { $0.backgroundColor }
        let average = UIColor.average(colors)
        return average
    }
}

extension ColorBarCollectionViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 0
    }
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 0
    }
}
