import Foundation

class Secrets {
    static var secrets: NSDictionary = {
        if let filePath = NSBundle.mainBundle().pathForResource("Secrets", ofType:"plist") {
            return NSDictionary(contentsOfFile: filePath) ?? NSDictionary()
        } else {
            return NSDictionary()
        }
    }()
    
    static func get<T>(key: String) -> T? {
        return self.secrets[key] as? T
    }
    
    static func getUrl(key: String) -> NSURL? {
        let urlString: String? = get(key)
        return urlString.flatMap { NSURL(string: $0) }
    }
}
