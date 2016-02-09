/*

Miscellanious math helper functions.

*/

import Foundation

func clamp<T : Comparable>(value: T, minVal: T, maxVal: T) -> T {
    return min(max(value, minVal), maxVal)
}
