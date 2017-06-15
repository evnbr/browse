//
//  HomeViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController, UIViewControllerTransitioningDelegate {

    var thumb : TabThumbnail!
    var snapshot : UIView!

    let thumbAnimationController = PresentTabAnimationController()

    
    var tab : WebViewController!
    
    lazy var settingsVC : SettingsViewController = SettingsViewController()
    lazy var bookmarksVC : BookmarksViewController = BookmarksViewController()

    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if tab != nil && tab.view.window != nil {
            return tab.preferredStatusBarStyle
        }
        else {
            return .lightContent
        }
    }
    override var prefersStatusBarHidden: Bool {
        return false
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        tab = WebViewController()
        tab.homeVC = self

        Settings.shared.updateProtocolRegistration()
        
        title = ""
        view.backgroundColor = .black

        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .blackTranslucent

        navigationController?.toolbar.tintColor = .white
        navigationController?.toolbar.barStyle = .blackTranslucent
        
//        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(showSettings))
        
//        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Bookmarks", style: .plain, target: self, action: #selector(showBookmarks))
        
        let bookmarkButton = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action:  #selector(showBookmarks))
//        navigationItem.rightBarButtonItem = bookmarks
        
        toolbarItems = [bookmarkButton]


        
        let aspect = UIScreen.main.bounds.width / UIScreen.main.bounds.height
        let H : CGFloat = 500.0
        thumb = TabThumbnail(frame: CGRect(x: 10, y: 50, width: aspect * H, height: H - 32) )
//        thumb = TabThumbnail(frame: CGRect(x: 10, y: 100, width: 300, height: 450) )
        thumb.backgroundColor = .white
        updateSnapshot()
        view.addSubview(thumb)
        
        let thumbTap = UITapGestureRecognizer(target: self, action: #selector(showTabAnimated))
        thumb.addGestureRecognizer(thumbTap)
        
        showTab(animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // TODO: this isnt working
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
        navigationController?.isToolbarHidden = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateSnapshot() {
        snapshot = tab.view.snapshotView(afterScreenUpdates: true)
        thumb.setSnapshot(snapshot)
    }

    
    // MARK - Presenting other views

    func showSettings() {
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    func showBookmarks() {
        bookmarksVC.homeVC = self
        navigationController?.pushViewController(bookmarksVC, animated: true)
    }
    
    func showTabAnimated() {
            showTab(animated: true)
    }
    
    func showTab(animated: Bool = true) {
        thumb.unSelect() // TODO this shou;d be somewhere else
        tab.modalPresentationStyle = .custom
        tab.transitioningDelegate = self

        present(tab, animated: animated)
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
