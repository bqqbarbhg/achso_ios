/*

Simple keyword search implementation.

`SearchIndex` manages an database of keywords that map to `SearchObject`s that is potentially slow to build but fast to query.

    let searchIndex = SearchIndex()

    for document in documents {
        let searchObject = SearchObject(tag: document.id)
        searchObject.feed(document.title)
        searchObject.feed(document.author.name)
        searchObject.feed(document.bodyText)
        searchIndex.add(searchObject)
    }

    let results = searchIndex.search("simple query")

*/

import Foundation

func keywordsFromText(text: String) -> Set<String> {
    
    // Note: This uses the current locale
    let lowercase = text.lowercaseStringWithLocale(NSLocale.currentLocale())
    let tokensAndEmpty = lowercase.componentsSeparatedByCharactersInSet(NSCharacterSet.alphanumericCharacterSet().invertedSet)
    let tokens = tokensAndEmpty.filter { !$0.isEmpty }
    
    // TODO: Stop words?
    
    return Set<String>(tokens)
}

class SearchObject {
    let tag: AnyObject
    var keywords = Set<String>()
    
    init(tag: AnyObject) {
        self.tag = tag
    }
    
    func feed(text: String) {
        keywords.unionInPlace(keywordsFromText(text))
    }
}

struct SearchResult {
    let object: SearchObject
    var score: Int
    
    init (object: SearchObject) {
        self.object = object
        self.score = 1
    }
}

class SearchIndex {
    var objectsForKeyword: [String: [SearchObject]] = [:]
    
    func add(searchObject: SearchObject) {
        for keyword in searchObject.keywords {
            objectsForKeyword[keyword]?.append(searchObject) ?? {
                objectsForKeyword[keyword] = [searchObject]
            }()
        }
    }
    
    func search(keyword keyword: String) -> [SearchObject] {
        return objectsForKeyword[keyword] ?? []
    }
    
    func search(keywords: Set<String>) -> [SearchResult] {
        var results = [SearchResult]()
        for keyword in keywords {
            for match in self.search(keyword: keyword) {
                if let index = results.indexOf({ $0.object === match }) {
                    results[index].score += 1
                } else {
                    results.append(SearchResult(object: match))
                }
            }
        }
        return results
    }
    
    func search(query: String) -> [SearchResult] {
        return self.search(keywordsFromText(query))
    }
}
