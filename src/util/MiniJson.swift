import Foundation

typealias JSONObject = [String : AnyObject]
typealias JSONArray = [AnyObject]

enum JSONError: ErrorType, PrintableError {
    case KeyNotFound(key: String)
    case KeyNotConvertible(key: String, type: String)
    
    var localizedErrorDescription: String {
        switch self {
        case .KeyNotFound(let key): return "[key '\(key)' not found]"
        case .KeyNotConvertible(let key, let type): return "[key '\(key)' not convertible to '\(type)']"
        }
    }
}

extension Dictionary {
    
    func castGet<T>(key: Key) throws -> T {
        guard let valueAny = self[key] else {
            throw JSONError.KeyNotFound(key: String(key))
        }
        guard let value = valueAny as? T else {
            throw JSONError.KeyNotConvertible(key: String(key), type: String(T.self))
        }
        return value
    }

}

func parseJson(string: String) -> JSONObject? {
    let options = NSJSONReadingOptions(rawValue: 0)
    guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else { return nil }
    guard let object = try? NSJSONSerialization.JSONObjectWithData(data, options: options) else {
        return nil
    }
    return object as? JSONObject
}

func stringifyJson(object: JSONObject) -> String? {
    let options = NSJSONWritingOptions(rawValue: 0)
    guard let data = try? NSJSONSerialization.dataWithJSONObject(object, options: options) else {
        return nil
    }
    return String(data: data, encoding: NSUTF8StringEncoding)
}
