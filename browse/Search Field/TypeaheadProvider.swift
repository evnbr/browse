//
//  TypeaheadProvider.swift
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

struct TypeaheadSuggestion: Hashable {
    let title: String
    let detail: String?
    let url: URL?
    
    var hashValue: Int {
        return url?.hashValue ?? 0
    }
    
    static func ==(lhs: TypeaheadSuggestion, rhs: TypeaheadSuggestion) -> Bool {
        return lhs.url == rhs.url
    }
}


class TypeaheadProvider: NSObject {
    static let shared = TypeaheadProvider()
    
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
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var isHistoryLoaded = false
        var isSuggestionLoaded = false
        
        var searchSuggestions: [ TypeaheadSuggestion ] = []
        var historySuggestions: [ TypeaheadSuggestion ] = []
        var suggestionScore : [ TypeaheadSuggestion : Int ] = [:]
        
        let maybeCompletion = {
            guard isHistoryLoaded && isSuggestionLoaded else { return }
            let sorted = (searchSuggestions + historySuggestions).sorted { suggestionScore[$0]! > suggestionScore[$1]! }
            let suggestions = Array(sorted[..<min(sorted.count, maxCount)])
            DispatchQueue.main.async { completion(suggestions) }
        }
        
        HistoryManager.shared.findItemsMatching(text) { visits in
            isHistoryLoaded = true
            if let results = visits {
                historySuggestions = results.map { item in
                    let score = self.splitMatchingScore(for: item, query: text)
                    
                    var suggestion : TypeaheadSuggestion
                    
                    if let q = item.url.searchQuery {
                        suggestion = TypeaheadSuggestion(title: q, detail: nil, url: item.url)
                    }
                    else {
                        suggestion = TypeaheadSuggestion(title: item.title, detail: item.url.cleanString, url: item.url)
                    }

                    suggestionScore[suggestion] = score
                    return suggestion
                }
            }
            maybeCompletion()
        }
        
        guard let url = provider.suggestionURLfor(text) else { return }
        
        //fetching the data from the url
        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) -> Void in
            isSuggestionLoaded = true
            if data == nil {
                searchSuggestions = [ TypeaheadSuggestion(title: "Unable to search", detail: error?.localizedDescription, url: nil)  ]
                maybeCompletion()
            }
            else if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSArray {
                searchSuggestions = self.provider.parseSuggestions(from: json, maxCount: maxCount).map({ str in
                    let score = self.splitMatchingScore(for: str, query: text)
                    let suggestion = TypeaheadSuggestion(title: str, detail: nil, url: self.serpURLfor(str))
                    suggestionScore[suggestion] = score
                    return suggestion
                })
                maybeCompletion()
            }
        }).resume()
    }
}


// History result scoring and sorting
extension TypeaheadProvider {
    func splitMatchingScore(for item: HistorySearchResult, query: String) -> Int {
        let inOrderScore = matchingScore(for: item, query: query)
        let splitScore = query.split(separator: " ")
            .map { matchingScore(for: item, query: String($0)) }
            .reduce(0, { $0 + $1 })
        return inOrderScore * 2 + splitScore
    }
    
    func splitMatchingScore(for text: String, query: String) -> Int {
        let inOrderScore = matchingScore(for: text, query: query)
        let splitScore = query.split(separator: " ")
            .map { matchingScore(for: text, query: String($0)) }
            .reduce(0, { $0 + $1 })
        return inOrderScore * 2 + splitScore
    }
    
    func matchingScore(for item: HistorySearchResult, query: String) -> Int {
        if query == "" { return 0 }
        var score : Float = 0
        score += Float(matchingScore(for: item.title, query: query))
        score += Float(matchingScore(for: item.url, query: query))
        return Int(score)
    }
    
    func matchingScore(for url: URL, query: String) -> Int {
        var score : Float = 0
        // Points for host matching
        if let host = url.host, host.localizedCaseInsensitiveContains(query) {
            let parts = host.split(separator: ".")
            parts.forEach { part in
                let partPct = Float(part.count) / Float(url.absoluteString.count) // bias against long urls
                let pct = Float(query.count) / Float(part.count)
                score += pct * partPct * ( part.starts(with: query) ? 200 : 60 )
            }
        }
        return Int(score)
    }
    
    func matchingScore(for text: String, query: String) -> Int {
        var score : Float = 0
        
        // Points for words in the title
        if text.localizedCaseInsensitiveContains(query) {
            let words = text.split(separator: " ")
            let maxWordScore : Float = 200 / Float(words.count)
            
            words.forEach { word in
                let partPct = Float(word.count) / Float(text.count) // bias against long urls
                let pct = Float(query.count) / Float(word.count)
                score += maxWordScore * pct * ( word.starts(with: query) ? 1 : 0.2 )
            }
        }
        return Int(score)
    }
}
