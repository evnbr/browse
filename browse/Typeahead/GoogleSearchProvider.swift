//
//  GoogleSearchProvider.swift
//  browse
//
//  Created by Evan Brooks on 3/7/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

class GoogleSearchProvider : SearchProvider {
    func serpURLfor(_ query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        return URL(string: "https://www.google.com/search?q=\(encodedQuery)")
    }
    
    func suggestionURLfor(_ query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        return URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(encodedQuery)")
    }
    
    func parseSuggestions(from data: NSArray, maxCount: Int) -> [String] {
        var phrases : [String] = []
        
        guard let suggestions = data[1] as? NSArray else { return phrases }
        for item in suggestions {
            if let phrase = item as? String, phrases.count < maxCount {
                phrases.append(phrase)
            }
        }
        return phrases
    }
}
