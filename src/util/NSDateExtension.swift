import Foundation

func <(a: NSDate, b: NSDate) -> Bool {
    return a.compare(b) == .OrderedAscending
}
func >(a: NSDate, b: NSDate) -> Bool {
    return a.compare(b) == .OrderedDescending
}
