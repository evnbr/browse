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
    
    private var authToken: String?

    var isLoggedIn: Bool {
        return authToken != nil
    }
    
    override init() {
        super.init()
        if let token = UserDefaults.standard.string(forKey: kPinboardAuthToken) {
            authToken = token
        }
    }

    func logOut() {
        authToken = nil
        UserDefaults.standard.removeObject(forKey: kPinboardAuthToken)
    }

    func setAuthToken(_ token: String, completion: @escaping (Bool) -> Void) {
        authToken = token
        
        fetch(method: "/posts/update?foo=bar") { json, _ in
            if let json = json, json["update_time"].string != nil {
                UserDefaults.standard.set(token, forKey: kPinboardAuthToken)
                completion(true)
            } else {
                self.authToken = nil
                completion(false)
            }
        }
    }

    func isBookmarked(_ url : URL?, completion: @escaping (Bool) -> Void) {
        guard let url = url else {
            completion(false)
            return
        }
        let toCheck = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

        fetch(method: "/posts/get?url=\(toCheck)") { json, _ in
            if let posts = json?["posts"].array {
                completion(posts.count > 0)
            } else {
                completion(false)
            }
        }
    }
    
    func addBookmark(_ url: URL, title: String, completion: @escaping (Bool) -> Void) {
        let urlString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let desc = title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        
        fetch(method: "/posts/add?url=\(urlString)&description=\(desc)") { json, _ in
            if let result = json?["result_code"].string {
                completion(result == "done")
            } else {
                completion(false)
            }
        }
    }

    func removeBookmark(_ url: URL, completion: @escaping (Bool) -> Void) {
        let urlString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

        fetch(method: "/posts/delete?url=\(urlString)") { json, _ in
            if let result = json?["result_code"].string {
                completion(result == "done")
            } else {
                completion(false)
            }
        }
    }

    private func fetch(method: String, completion: @escaping (JSON?, Error?) -> Void ) {
        guard let authToken = authToken else { return }

        let str = "https://api.pinboard.in/v1\(method)&auth_token=\(authToken)&format=json"
        guard let url = URL(string: str) else {
            print("Malformed url: \(str)")
            return
        }

        URLSession.shared.dataTask(with: url, completionHandler: {(data, _, error) -> Void in
            if data == nil {
                print(error?.localizedDescription ?? "Unknown failure")
                completion(nil, error)
            }
            if let data = data {
                if let parsed = try? JSON(data: data) {
                    completion(parsed, nil)
                }
            }
        }).resume()

    }
}
