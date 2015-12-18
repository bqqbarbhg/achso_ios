import Foundation

extension Array {
    subscript (safe index: Int) -> Element? {
        if index >= 0 && index < self.count {
            return self[index]
        } else {
            return nil
        }
    }
}

extension SequenceType {
    
    func groupBy<U : Hashable>(@noescape groupFor: Generator.Element -> U) -> [U: [Generator.Element]] {
        var result: [U: [Generator.Element]] = [:]
        for element in self {
            let key = groupFor(element)
            result[key]?.append(element) ?? {
                result[key] = [element]
            }()
            
        }
        return result
    }
    
    func find(@noescape predicate: (Self.Generator.Element) throws -> Bool) rethrows -> Self.Generator.Element? {
        for element in self {
            if try predicate(element) { return element }
        }
        return nil
    }
}
