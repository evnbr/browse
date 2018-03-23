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

struct TypeaheadSuggestion {
    let title: String
    let detail: String?
    let url: URL?
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

    func suggestions(for text: String, maxCount: Int = .max, completion: @escaping ([TypeaheadSuggestion]) -> Void) {
        var isHistoryLoaded = false
        var isSuggestionLoaded = false
        
        var suggestions: [ TypeaheadSuggestion ] = []
        var firstHistoryItem: TypeaheadSuggestion? = nil
        
        let maybeCompletion = {
            if isHistoryLoaded && isSuggestionLoaded {
                if let item = firstHistoryItem {
                    suggestions.insert(item, at: 0)
                    suggestions.removeLast()
                }
                DispatchQueue.main.async {
                    completion(suggestions)
                }
            }
        }
        
        HistoryManager.shared.fetchItemsContaining(text) { results in
            isHistoryLoaded = true
            if let page = results?.first {
                firstHistoryItem = TypeaheadSuggestion(title: page.url.cleanString, detail: page.title, url: page.url)
            }
            maybeCompletion()
        }
        
        guard let url = provider.suggestionURLfor(text) else { return }
        
        //fetching the data from the url
        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) -> Void in
            isSuggestionLoaded = true
            if data == nil {
                suggestions = [ TypeaheadSuggestion(title: "Unable to search", detail: error?.localizedDescription, url: nil)  ]
                maybeCompletion()
            }
            else if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSArray {
                suggestions = self.provider.parseSuggestions(from: json, maxCount: maxCount).map({ str in
                    return TypeaheadSuggestion(title: str, detail: nil, url: self.serpURLfor(str))
                })
                maybeCompletion()
            }
        }).resume()
    }
}
