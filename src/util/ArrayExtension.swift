import Foundation

extension Array {

    // Safe subscript operator, return nil if not found
    subscript (safe index: Int) -> Element? {
        if index >= 0 && index < self.count {
            return self[index]
        } else {
            return nil
        }
    }

}

extension SequenceType {

    // Find the first element matching `predicate`, nil if not found
    func find(@noescape predicate: (Self.Generator.Element) throws -> Bool) rethrows -> Self.Generator.Element? {
        for element in self {
            if try predicate(element) { return element }
        }
        return nil
    }
}
