/*

Miscellanious date and time helper functions.

Defines `iso8601DateFormatter` for parsing and writing to the Ach so! manifest format.

*/

import Foundation

var iso8601DateFormatter: NSDateFormatter = {
    let dateFormatter = NSDateFormatter()
    dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSSxxx"

    return dateFormatter
}()

