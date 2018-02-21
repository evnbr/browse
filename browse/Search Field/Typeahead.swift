//
//  Typeahead.swift
//  browse
//
//  Created by Evan Brooks on 2/4/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import Foundation

// ddg search results:
class Typeahead: NSObject {
    static let shared = Typeahead()
    
    
    func urlForQuery(_ query: String) -> URL? {
//        return URL(string: "https://duckduckgo.com/ac/?q=\(query)")
        return URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(query)")
    }
    
    func parseStrings(from suggestions: NSArray, maxCount: Int = .max) -> [String] {
        return parseGoogle(from: suggestions, maxCount: maxCount)
    }
    
    func parseDuckDuckGo(from data: NSArray, maxCount: Int) -> [String] {
        var phrases : [String] = []
        for item in data {
            if let dict = item as? NSDictionary,
                phrases.count < maxCount,
                let phrase = dict.value(forKey: "phrase") as? String {
                phrases.append(phrase)
            }
        }
        return phrases
    }

    func parseGoogle(from data: NSArray, maxCount: Int) -> [String] {
        var phrases : [String] = []
        
        guard let suggestions = data[1] as? NSArray else { return phrases }
        for item in suggestions {
            if let phrase = item as? String, phrases.count < maxCount {
                phrases.append(phrase)
            }
        }
        return phrases
    }

    
    func suggestions(for text: String, maxCount: Int = .max, completion: @escaping ([String]) -> Void) {
        let query = text.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        guard let url = urlForQuery(query) else { return }
        
        //fetching the data from the url
        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) -> Void in
            if let suggestions = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSArray {
                let phrases = self.parseStrings(from: suggestions, maxCount: maxCount)
                DispatchQueue.main.async { completion(phrases) }
            }
        }).resume()
    }
    
}
