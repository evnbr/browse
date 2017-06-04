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

    let thumbAnimationController = CustomAnimationController()

    
    var tab : WebViewController!
    lazy var settingsVC : SettingsViewController = SettingsViewController()
    lazy var bookmarksVC : BookmarksViewController = BookmarksViewController()

    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    override var prefersStatusBarHidden: Bool {
        return false
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        tab = WebViewController()
        tab.homeVC = self

        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .blackTranslucent
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(showSettings))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Bookmarks", style: .plain, target: self, action: #selector(showBookmarks))

        view.backgroundColor = .black

        title = "Browser"
        
        let aspect = UIScreen.main.bounds.width / UIScreen.main.bounds.height
        let H : CGFloat = 300.0
        thumb = TabThumbnail(frame: CGRect(x: 10, y: 100, width: aspect * H, height: H) )
        thumb.backgroundColor = .white
        updateSnapshot()
        view.addSubview(thumb)
        
        let thumbTap = UITapGestureRecognizer(target: self, action: #selector(showTab))
        thumb.addGestureRecognizer(thumbTap)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // TODO: this isnt working
        setNeedsStatusBarAppearanceUpdate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateSnapshot() {
        print("update snapshot")
        if snapshot != nil { snapshot.removeFromSuperview() }
        snapshot = tab.view.snapshotView(afterScreenUpdates: true)
        snapshot.frame = CGRect(origin: .zero, size: thumb.frame.size)
//        snapshot.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        thumb.addSubview(snapshot)
//        let h = NSLayoutConstraint(item: snapshot, attribute: .height, relatedBy: .equal, toItem: thumb, attribute: .height, multiplier: 1, constant: 1)
//        let w = NSLayoutConstraint(item: snapshot, attribute: .width, relatedBy: .equal, toItem: thumb, attribute: .width, multiplier: 1, constant: 1)
//        thumb.addConstraints([w, h])
    }

    
    // MARK - Presenting other views

    func showSettings() {
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    func showBookmarks() {
        bookmarksVC.homeVC = self
        navigationController?.pushViewController(bookmarksVC, animated: true)
    }
    
    func showTab() {
        thumb.unSelect() // TODO this shou;d be somewhere else
        tab.modalPresentationStyle = .custom
        tab.transitioningDelegate = self

        present(tab, animated: true)
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
