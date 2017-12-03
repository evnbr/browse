//
//  BookmarksViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

let BOOKMARKS_GLOBAL : [ String ] = [
    "apple.com",
    "evanbrooks.info",
    "evanbrooks.info/bindery",
    "dropbox.design",
    "github.com",
    "figma.com",
    "framer.com",
    "hoverstat.es",
    "nytimes.com",
    "bloomberg.com",
    "moodringnyc.com",
    "theverge.com",
    "theoutline.com",
    "bacca.online",
    "marygaudin.com",
    "instagram.com",
    "facebook.com",
    "twitter.com",
    "medium.com",
    "amazon.com",
    "fonts.google.com",
    "flights.google.com",
    "plus.google.com",
    "maps.google.com",
    "wikipedia.org",
    "tachyons.io",
    "postlight.com",
    "playlab.org"
]

class BookmarksViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let bookmarks = BOOKMARKS_GLOBAL
    var homeVC : HomeViewController!
    var browserVC : BrowserViewController!
    
    private var table: UITableView!

    override func loadView() {
        super.loadView()
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Bookmarks"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .blackTranslucent
        
        
        table = UITableView(frame:self.view.frame)

        table.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
        table.dataSource = self
        table.delegate = self
        self.view.addSubview(table)
        
        view.backgroundColor = .black
        table.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        table.separatorColor = UIColor.white.withAlphaComponent(0.1)

        
//        navigationController?.isToolbarHidden = false
        let toolbar = navigationController?.toolbar
//        toolbar?.isTranslucent = false
        toolbar?.barTintColor = .black
        toolbar?.tintColor = .white
        
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSelf))
        navigationItem.rightBarButtonItem = done
        

    }
    
    
    override func viewWillAppear(_ animated: Bool) {
//        table.setContentOffset(table.contentInset  , animated: false)
        table.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        
        navigationController?.isNavigationBarHidden = false
        navigationController?.isToolbarHidden = true

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.setNeedsStatusBarAppearanceUpdate()
        
    }
    
    @objc func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        if browserVC != nil {
            dismissSelf()
            browserVC.navigateToText(bookmarks[indexPath.row])
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let remove = UITableViewRowAction(style: .destructive, title: "Remove", handler: { (action, indexPath) in
            print("Remove \(indexPath.row)")
        })
        return [remove]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell", for: indexPath as IndexPath)
        for subview in cell.contentView.subviews { subview.removeFromSuperview() }

        cell.textLabel!.text = "\(bookmarks[indexPath.row])"
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .clear
        
        let bv = UIView()
        bv.backgroundColor = UIColor(white: 0.2, alpha: 1)
        cell.selectedBackgroundView = bv
        
        return cell
    }

}
