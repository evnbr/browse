//
//  AppDelegate.swift
//  browse
//
//  Created by Evan Brooks on 5/11/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var navController: UINavigationController!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
    ) -> Bool {
//        self.window?.layer.speed = 0.1
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("Will resign active...")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        HistoryManager.shared.saveViewContext()
        print("Did enter bg...")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("Will terminate...")
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("Memory warning")
    }

}
