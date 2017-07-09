//
//  HomeViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit


let THUMB_H : CGFloat = 200.0

class HomeViewController: UICollectionViewController, UIViewControllerTransitioningDelegate {

    var tabs : [WebViewController] = []
    var snapshots : [UIView] = []
    
    let reuseIdentifier = "TabCell"
    let sectionInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
    let itemsPerRow : CGFloat = 2
    
    var selectedTab : WebViewController?

    let thumbAnimationController = PresentTabAnimationController()
    
    var scroll : UIScrollView!
    
    lazy var settingsVC : SettingsViewController = SettingsViewController()
    lazy var bookmarksVC : BookmarksViewController = BookmarksViewController()

    var gradientLayer : CAGradientLayer!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard let webVC = selectedTab else { return .lightContent }
        if webVC.view.window != nil && !webVC.isBeingDismissed {
            return webVC.preferredStatusBarStyle
        }
        return .lightContent
    }
    override var prefersStatusBarHidden: Bool {
        guard let webVC = selectedTab else { return false }
        if webVC.view.window != nil && !webVC.isBeingDismissed {
            return webVC.prefersStatusBarHidden
        }

        return false
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.delaysContentTouches = false
        collectionView?.alwaysBounceVertical = true
        collectionView?.indicatorStyle = .white
        collectionView?.register(TabThumbnail.self, forCellWithReuseIdentifier: reuseIdentifier)

        Settings.shared.updateProtocolRegistration()
        
        title = ""
        view.backgroundColor = .black
        collectionView?.backgroundColor = .black
        
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .blackTranslucent
        
        navigationController?.toolbar.tintColor = .white
        navigationController?.toolbar.barStyle = .blackTranslucent
        navigationController?.toolbar.isTranslucent = false
        navigationController?.isToolbarHidden = false
        
        let addButton = ToolbarTextButton(
            title: "New",
            withIcon: UIImage(named: "tab"),
            onTap: self.addTab
        )
                
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(customView: addButton),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
        ]
        
        let tab1 = WebViewController(home: self)
        tabs = [tab1]


//        gradientLayer = CAGradientLayer()
//        gradientLayer.frame = view.bounds
//        gradientLayer.colors = [
//            UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.7).cgColor,
//            UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 1.0).cgColor]
//        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0);
//        gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.1);
//        view.layer.mask = gradientLayer;

                
        navigationController?.view.alpha = 0.0
        showTab(tab: tabs[0], animated: false)
    }
    
    override func viewWillLayoutSubviews() {
        gradientLayer?.frame = view.bounds
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateCollectionViewLayout(with: size)
    }
    
    private func updateCollectionViewLayout(with size: CGSize) {
        if let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
//            layout.itemSize = (size.width < size.height) ? itemSizeForPortraitMode : itemSizeForLandscapeMode
            layout.invalidateLayout()
        }
    }

    func addTab() {
        let newTab = WebViewController(home: self)
        self.showTab(tab: newTab)

        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            self.tabs.append(newTab)
            self.collectionView?.insertItems(at: [ IndexPath(item: self.tabs.index(of: newTab)!, section: 0) ])
        }
    }
    
    func showRenameThis(_ tab: WebViewController) {
        showTab(tab: tab)
    }
    
    func thumb(forTab webVC: WebViewController) -> TabThumbnail! {
        //return collectionView?.visibleCells.first as! TabThumbnail!
        return collectionView?.visibleCells.first(where: { (cell) -> Bool in
            let thumb = cell as! TabThumbnail
            return thumb.webVC == webVC
        }) as! TabThumbnail!
    }
    
    func showTab(tab: WebViewController, animated: Bool = true) {
        selectedTab = tab
        
        tab.modalPresentationStyle = .custom
        tab.transitioningDelegate = self
        
        present(tab, animated: animated)
    }
    
    func updateThumbnail(tab: WebViewController) {
        thumb(forTab: tab).updateSnapshot()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
//        navigationController?.isToolbarHidden = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK - Presenting other views

    func showSettings() {
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    func showBookmarks() {
        bookmarksVC.homeVC = self
        navigationController?.pushViewController(bookmarksVC, animated: true)
    }
    

    
    // MARK - Animation
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        thumbAnimationController.direction = .present
        return thumbAnimationController
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        thumbAnimationController.direction = .dismiss
        return thumbAnimationController
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

// MARK: - UICollectionViewDataSource
extension HomeViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabs.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                      for: indexPath) as! TabThumbnail
        // Configure the cells
        
        cell.webVC = tabs[indexPath.row]
        cell.closeTabCallback = closeTab
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        showTab(tab: tabs[indexPath.row])
    }
    
    func closeTab(fromCell cell: UICollectionViewCell) {
        if let path = collectionView?.indexPath(for: cell) {
            tabs.remove(at: path.row)
            collectionView?.deleteItems(at: [path])
        }
    }
    
    var thumbSize : CGSize {
        if view.frame.width > 400 {
            let ratio = view.frame.width / THUMB_H
            let w = view.frame.width / 2 - 16
            return CGSize(width: w, height: w / ratio )
        }
        return CGSize(width: view.frame.width - 16, height: THUMB_H)
    }
    
    
}

extension HomeViewController : UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        //2
//        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
//        let availableWidth = view.frame.width - paddingSpace
//        let widthPerItem = availableWidth / itemsPerRow
        return thumbSize
    }
    
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForItem section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8.0
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 moveItemAt source: IndexPath,
                                 to destination: IndexPath) {
        let item = tabs.remove(at: source.item)
        tabs.insert(item, at: destination.item)
    }
    
    
}


