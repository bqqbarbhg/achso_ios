import Foundation

typealias JSONObject = [String : AnyObject]
typealias JSONArray = [AnyObject]

enum JSONError: ErrorType {
    case KeyNotFound
    case KeyNotConvertible
}

extension Dictionary {
    
    func castGet<T>(key: Key) throws -> T {
        guard let valueAny = self[key] else {
            throw JSONError.KeyNotFound
        }
        guard let value = valueAny as? T else {
            throw JSONError.KeyNotConvertible
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
