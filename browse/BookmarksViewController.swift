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
        "figma.com",
        "hoverstat.es",
        "amazon.com",
        "fonts.google.com",
        "flights.google.com",
        "maps.google.com",
        "plus.google.com",
        "wikipedia.org",
        "theoutline.com",
        "corndog.love",
    ]
    
    var sender : WebViewController!
    
    lazy var settingsVC : SettingsViewController = SettingsViewController()

    
    private var table: UITableView!

    override func loadView() {
        super.loadView()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Bookmarks"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissSelf))
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(showSettings))
        
        table = UITableView(frame:self.view.frame)
        table.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
        table.dataSource = self
        table.delegate = self
        self.view.addSubview(table)
    }
        
    func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func showSettings() {
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if sender != nil {
            dismissSelf()
            sender.navigateToText(bookmarks[indexPath.row])
            table.deselectRow(at: indexPath, animated: true)
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
        
        cell.textLabel!.text = "\(bookmarks[indexPath.row])"
        
        return cell
    }

}
