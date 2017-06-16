//
//  HomeViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController, UIViewControllerTransitioningDelegate {

//    var thumb : TabThumbnail!
    var thumbs : [TabThumbnail] = []
    var tabs : [WebViewController] = []

    let thumbAnimationController = PresentTabAnimationController()

    var tab : WebViewController!
    
    var scroll : UIScrollView!
    
    lazy var settingsVC : SettingsViewController = SettingsViewController()
    lazy var bookmarksVC : BookmarksViewController = BookmarksViewController()

    
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if tab != nil && tab.view.window != nil && !tab.isBeingDismissed {
            return tab.preferredStatusBarStyle
        }
        return .lightContent
    }
    override var prefersStatusBarHidden: Bool {
        if tab != nil && tab.view.window != nil && !tab.isBeingDismissed {
            return tab.prefersStatusBarHidden
        }

        return false
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        scroll = UIScrollView(frame: view.frame)
        view.addSubview(scroll)
        scroll.alwaysBounceVertical = false
        scroll.indicatorStyle = .white
        scroll.isDirectionalLockEnabled = true
        scroll.isPagingEnabled = false
        scroll.delaysContentTouches = false
        scroll.contentSize = CGSize(width: 1600, height: 500)
        
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        tab = WebViewController()
        let tab2 = WebViewController()
        let tab3 = WebViewController()
        tabs = [tab, tab2, tab3]

        
        Settings.shared.updateProtocolRegistration()
        
        title = ""
        view.backgroundColor = .black

        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .blackTranslucent

        navigationController?.toolbar.tintColor = .white
        navigationController?.toolbar.barStyle = .blackTranslucent

        
        let aspect = UIScreen.main.bounds.width / UIScreen.main.bounds.height
        let THUMB_H : CGFloat = 500.0
        let THUMB_W : CGFloat = aspect * THUMB_H

        for i in 0 ... 2 {
            let t = TabThumbnail(
                frame: CGRect(
                    x: 10 + (THUMB_W + 8) * CGFloat(i),
                    y: 50,
                    width: THUMB_W,
                    height: THUMB_H - 40
                ),
                tab: tabs[i],
                onTap: showRenameThis
            )
            t.center.y = view.center.y

            scroll.addSubview(t)
            thumbs.append(t)
        }
        
        thumbs[0].isHidden = true
        
        
        showTab(tab: tab, animated: false)
    }
    
    func showRenameThis(_ tab: WebViewController) {
        showTab(tab: tab)
    }
    
    func thumb(forTab tab: WebViewController) -> TabThumbnail! {
        return thumbs.first(where: { $0.tab == tab })
    }
    
    func showTab(tab: WebViewController, animated: Bool = true) {
        thumb(forTab: tab).unSelect() // TODO this should be somewhere else
        
        tab.modalPresentationStyle = .custom
        tab.transitioningDelegate = self
        
        present(tab, animated: animated)
    }

    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
//        navigationController?.isToolbarHidden = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
//    func updateSnapshot() {
//        snapshot = tab.view.snapshotView(afterScreenUpdates: true)
//        thumb.setSnapshot(snapshot)
//    }

    
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
