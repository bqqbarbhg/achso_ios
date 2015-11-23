import Foundation

protocol PrintableError {
    var localizedErrorDescription: String { get }
}

extension NSError: PrintableError {
    var localizedErrorDescription: String {
        return self.localizedDescription
    }
}

class AssertionError: ErrorType, PrintableError {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
    
    var localizedErrorDescription: String {
        return "Assertion failed: \(self.description)"
    }
}

class DebugError: ErrorType, PrintableError {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
    
    var localizedErrorDescription: String {
        return "[\(self.description)]"
    }
}

class UserError: ErrorType, PrintableError {
    let description: String
    let innerError: PrintableError?
    
    init(_ description: String, innerError: PrintableError?) {
        self.description = description
        self.innerError = innerError
    }
    
    convenience init(_ description: String) {
        self.init(description, innerError: nil)
    }
    
    var localizedErrorDescription: String {
        var description = self.description
        
        if let innerError = self.innerError {
            description.appendContentsOf("\n\(innerError.localizedErrorDescription)")
        }
        
        return description
    }
    
    func withInnerError(error: PrintableError) -> UserError {
        return UserError(self.description, innerError: error)
    }
    
    func withDebugError(description: String) -> UserError {
        return withInnerError(DebugError(description))
    }
    
    static var invalidLayersBoxUrl: UserError {
        return UserError("Invalid Layers Box URL")
    }
    
    static var failedToAuthenticate: UserError {
        return UserError("Failed to authenticate with Layers Box")
    }
}
