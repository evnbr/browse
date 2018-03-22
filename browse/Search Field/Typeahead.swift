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
        var isHistoryLoaded = false
        var isSuggestionLoaded = false
        
        var phrases: [ String ] = []
        var firstHistoryItem: URL? = nil
        
        let maybeCompletion = {
            if isHistoryLoaded && isSuggestionLoaded {
                if let url = firstHistoryItem {
                    phrases.insert(url.cleanString, at: 0)
                    phrases.removeLast()
                }
                DispatchQueue.main.async {
                    print(phrases)
                    completion(phrases)
                }
            }
        }
        
        HistoryManager.shared.fetchItemsContaining(text) { urls in
            isHistoryLoaded = true
            firstHistoryItem = urls?.first
            maybeCompletion()
        }
        
        guard let url = provider.suggestionURLfor(text) else { return }
        
        //fetching the data from the url
        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) -> Void in
            isSuggestionLoaded = true
            if data == nil {
                phrases = [ error?.localizedDescription ?? "Unknown failure" ]
                maybeCompletion()
            }
            else if let suggestions = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSArray {
                phrases = self.provider.parseSuggestions(from: suggestions, maxCount: maxCount)
                maybeCompletion()
            }
        }).resume()
    }
}
