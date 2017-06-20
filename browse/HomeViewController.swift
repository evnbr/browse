//
//  HomeViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit


let THUMB_H : CGFloat = 200.0

class HomeViewController: UIViewController, UIViewControllerTransitioningDelegate {

//    var thumb : TabThumbnail!
    var thumbs : [TabThumbnail] = []
    var tabs : [WebViewController] = []
    
    var selectedTabIndex : Int = 0
    var selectedTab : WebViewController? {
        guard tabs.count > selectedTabIndex else { return nil }
        return tabs[selectedTabIndex]
    }

    let thumbAnimationController = PresentTabAnimationController()
    
    var scroll : UIScrollView!
    
    lazy var settingsVC : SettingsViewController = SettingsViewController()
    lazy var bookmarksVC : BookmarksViewController = BookmarksViewController()

    var gradientLayer : CAGradientLayer!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard let tab = selectedTab else { return .lightContent }
        if tab.view.window != nil && !tab.isBeingDismissed {
            return tab.preferredStatusBarStyle
        }
        return .lightContent
    }
    override var prefersStatusBarHidden: Bool {
        guard let tab = selectedTab else { return false }
        if tab.view.window != nil && !tab.isBeingDismissed {
            return tab.prefersStatusBarHidden
        }

        return false
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        scroll = UIScrollView(frame: view.frame)
        view.addSubview(scroll)
        //        scroll.alwaysBounceVertical = false
        scroll.alwaysBounceHorizontal = false
        scroll.indicatorStyle = .white
        scroll.isDirectionalLockEnabled = true
        scroll.isPagingEnabled = false
        scroll.delaysContentTouches = false
        scroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: 1600)

        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        Settings.shared.updateProtocolRegistration()
        
        title = ""
        view.backgroundColor = .black
        
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .blackTranslucent
        
        navigationController?.toolbar.tintColor = .white
        navigationController?.toolbar.barStyle = .blackTranslucent

        
        
        let tab1 = WebViewController(home: self)
        let tab2 = WebViewController(home: self)
        let tab3 = WebViewController(home: self)
        let tab4 = WebViewController(home: self)
        tabs = [tab1, tab2, tab3, tab4]


//        gradientLayer = CAGradientLayer()
//        gradientLayer.frame = view.bounds
//        gradientLayer.colors = [
//            UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.7).cgColor,
//            UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 1.0).cgColor]
//        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0);
//        gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.1);
//        view.layer.mask = gradientLayer;

        
        for i in 0 ... 3 {
            let t = TabThumbnail(
                frame: CGRect(
                    x: 0,
                    y: 10 + (THUMB_H + 8) * CGFloat(i),
                    width: UIScreen.main.bounds.width - 0,
                    height: THUMB_H
                ),
                tab: tabs[i],
                onTap: showRenameThis
            )
            
            scroll.addSubview(t)
            thumbs.append(t)
        }

        thumbs[selectedTabIndex].isHidden = true
        navigationController?.view.alpha = 0.0
        
        showTab(tab: selectedTab!, animated: false)
    }
    
    override func viewWillLayoutSubviews() {
        gradientLayer?.frame = view.bounds
    }

    
    func showRenameThis(_ tab: WebViewController) {
        showTab(tab: tab)
    }
    
    func thumb(forTab tab: WebViewController) -> TabThumbnail! {
        return thumbs.first(where: { $0.tab == tab })
    }
    
    func showTab(tab: WebViewController, animated: Bool = true) {
        selectedTabIndex = tabs.index(of: tab)!
        thumb(forTab: tab).unSelect() // TODO this should be somewhere else
        
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
