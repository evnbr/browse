//
//  BookmarksViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

class BookmarksViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let bookmarks : Array<String> = [
        "apple.com",
        "fonts.google.com",
        "flights.google.com",
        "maps.google.com",
        "plus.google.com",
        "wikipedia.org",
        "theoutline.com",
        "corndog.love",
    ]
    
    var sender : SiteViewController!

    
    private var table: UITableView!

    override func loadView() {
        super.loadView()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Bookmarks"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissSelf))
        

        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        
        table = UITableView(frame: CGRect(x: 0, y: 0, width: displayWidth, height: displayHeight))
        table.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
        table.dataSource = self
        table.delegate = self
        self.view.addSubview(table)
    }
    
    func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if sender != nil {
            dismissSelf()
            sender.goToText(bookmarks[indexPath.row])
            table.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell", for: indexPath as IndexPath)
        cell.textLabel!.text = "\(bookmarks[indexPath.row])"
        return cell
    }

}
