import Foundation

class UnwrapError: ErrorType {
    
}

extension Optional {
    func unwrap() throws -> Wrapped {
        switch (self) {
        case .None: throw UnwrapError()
        case .Some(let wrapped): return wrapped
        }
    }
}
