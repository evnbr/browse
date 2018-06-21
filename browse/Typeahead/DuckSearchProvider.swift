//
//  DuckSearchProvider.swift
//  browse
//
//  Created by Evan Brooks on 3/7/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

class DuckSearchProvider: SearchProvider {
    func serpURLfor(_ query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        return URL(string: "https://duckduckgo.com/?q=\(encodedQuery)")
    }

    func suggestionURLfor(_ query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        return URL(string: "https://duckduckgo.com/ac/?q=\(encodedQuery)")
    }

    func parseSuggestions(from data: NSArray, maxCount: Int) -> [String] {
        var phrases: [String] = []
        for item in data {
            if let dict = item as? NSDictionary,
                phrases.count < maxCount,
                let phrase = dict.value(forKey: "phrase") as? String {
                phrases.append(phrase)
            }
        }
        return phrases
    }
}
