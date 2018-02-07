//
//  TypeaheadController.swift
//  browse
//
//  Created by Evan Brooks on 2/4/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import Foundation

// ddg search results:


class Typeahead: NSObject {
    static let shared = Typeahead()
    
    func suggestions(for text: String, completion: @escaping ([String]) -> Void) {
        let query = text.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        guard let url = URL(string: "https://duckduckgo.com/ac/?q=\(query)") else { return }
        
        //fetching the data from the url
        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) -> Void in
            
            if let suggestions = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSArray {
                
                var phrases : [String] = []
                for item in suggestions {
                    if let dict = item as? NSDictionary {
                        if let phrase = dict.value(forKey: "phrase") as? String {
                            phrases.append(phrase)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(phrases)
                }
            }
        }).resume()
    }
}
