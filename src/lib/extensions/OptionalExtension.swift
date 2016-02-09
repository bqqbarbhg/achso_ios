import Foundation

class UnwrapError: ErrorType {
    let target: String
    
    init(target: String) {
        self.target = target
    }
}

extension Optional {
    
    // Throwing unwrap, like opt! but safer
    func unwrap() throws -> Wrapped {
        switch (self) {
        case .None: throw UnwrapError(target: String(Wrapped.self))
        case .Some(let wrapped): return wrapped
        }
    }
}
