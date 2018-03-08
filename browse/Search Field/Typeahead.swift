//
//  Typeahead.swift
//  browse
//
//  Created by Evan Brooks on 2/4/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import Foundation

fileprivate enum SearchProviderName : String {
    case google = "google"
    case duck = "duckduckgo"
}

class Typeahead: NSObject {
    static let shared = Typeahead()
    
    fileprivate var provider : SearchProvider = DuckSearchProvider()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(updateSearchProvider),
            name: UserDefaults.didChangeNotification ,
            object: UserDefaults.standard
        )
        updateSearchProvider()
    }
    
    @objc func updateSearchProvider() {
        if let str = UserDefaults.standard.value(forKey: "search_provider") as? String,
            let lastProvider = SearchProviderName(rawValue: str) {
            if lastProvider == .duck {
                provider = DuckSearchProvider()
            }
            else if lastProvider == .google {
                provider = GoogleSearchProvider()
            }
        }
    }
    
    func serpURLfor(_ query: String) -> URL? {
        return provider.serpURLfor(query)
    }

    func suggestions(for text: String, maxCount: Int = .max, completion: @escaping ([String]) -> Void) {
        guard let url = provider.suggestionURLfor(text) else { return }
        
        //fetching the data from the url
        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) -> Void in
            if data == nil {
                DispatchQueue.main.async {
                    completion([ error?.localizedDescription ?? "Unknown failure" ])
                }
                return
            }
            if let suggestions = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSArray {
                let phrases = self.provider.parseSuggestions(from: suggestions, maxCount: maxCount)
                DispatchQueue.main.async { completion(phrases) }
            }
        }).resume()
    }
}
