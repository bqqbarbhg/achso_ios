import Foundation

// Add comparison operators for NSDate objects

func <(a: NSDate, b: NSDate) -> Bool {
    return a.compare(b) == .OrderedAscending
}
func >(a: NSDate, b: NSDate) -> Bool {
    return a.compare(b) == .OrderedDescending
}
