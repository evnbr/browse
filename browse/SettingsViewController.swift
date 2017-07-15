//
//  SettingsViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/27/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    lazy var settings: [SettingsSection] = Settings.shared.sections
    
    var sender : BrowserViewController!
    
    
    private var table: UITableView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Settings"
                
        table = UITableView(frame: self.view.bounds, style: .grouped)
        table.allowsSelection = false
//        table.register(SettingsTableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        table.register(SettingsTableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        table.dataSource = self
        table.delegate = self
        self.view.addSubview(table)
        
        view.backgroundColor = .black
        table.backgroundColor = .black
        
        table.separatorColor = UIColor.white.withAlphaComponent(0.1)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if sender != nil {
            print("tapped \(indexPath.row)")
//            dismissSelf()
//            sender.navigateToText(bookmarks[indexPath.row])
//            table.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return settings.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return settings[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settings[section].numberOfItems
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath as IndexPath) as! SettingsTableViewCell
        
        let item = settings[indexPath.section][indexPath.row]
        
        cell.textLabel!.text = "\(item.title)"
        cell.item = item
        cell.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        cell.textLabel?.textColor = .white

        if item.style == .toggle {
            let toggle = UISwitch()
            toggle.isOn = item.isOn
            
//            toggle.thumbTintColor = .darkGray
//            toggle.onTintColor = .white
            toggle.tintColor = UIColor.white.withAlphaComponent(0.1)
            
            toggle.addTarget(cell, action: #selector(cell.toggleSwitch), for: .valueChanged)
            cell.accessoryView = toggle
            
        }

    
        return cell
    }

}

