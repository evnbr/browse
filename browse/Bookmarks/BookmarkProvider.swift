//
//  BookmarkProvider.swift
//  browse
//
//  Created by Evan Brooks on 3/7/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import SwiftyJSON

fileprivate let kPinboardAuthToken = "pinboard_auth_token"

class BookmarkProvider: NSObject {
    static let shared = BookmarkProvider()
    
    private var authToken : String?
    
    var isLoggedIn : Bool {
        return authToken != nil
    }
    
    override init() {
        super.init()
        if let token = UserDefaults.standard.string(forKey: kPinboardAuthToken) {
            authToken = token
        }
    }
    
    func setAuthToken(_ token : String, completion: @escaping (Bool) -> ()) {
        authToken = token
        
        fetch(method: "/posts/update?foo=bar") { json, error in
            if let json = json, json["update_time"].string != nil {
                UserDefaults.standard.set(token, forKey: kPinboardAuthToken)
                completion(true)
            }
            else {
                self.authToken = nil
                completion(false)
            }
        }
    }
    
    func isBookmarked(_ url : URL, completion: @escaping (Bool) -> ()) {
        let toCheck = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

        fetch(method: "/posts/get?url=\(toCheck)") { json, error in
            if let posts = json?["posts"].array {
                completion(posts.count > 0)
            }
            else { completion(false) }
        }
    }
    
    private func fetch(method: String, completion: @escaping (JSON?, Error?) -> () ) {
        guard let authToken = authToken else {
            print("Missing auth token")
            return
        }
        
        let str = "https://api.pinboard.in/v1\(method)&auth_token=\(authToken)&format=json";
        guard let url = URL(string: str) else {
            print("Malformed url: \(str)")
            return
        }

        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) -> Void in
            if data == nil {
                print(error?.localizedDescription ?? "Unknown failure")
                completion(nil, error)
            }
            if let data = data {
                completion(JSON(data: data), nil)
            }
        }).resume()

    }
}
