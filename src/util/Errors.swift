import UIKit

protocol PrintableError {
    var localizedErrorDescription: String { get }
}

extension NSError: PrintableError {
    var localizedErrorDescription: String {
        return self.localizedDescription
    }
}

extension UnwrapError: PrintableError {
    var localizedErrorDescription: String {
        return "[failed to unwrap \(self.target)]"
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
    let innerError: ErrorType?
    let fix: (title: String, action: UIViewController -> ())?

    init(_ description: String, innerError: ErrorType?) {
        self.description = description
        self.innerError = innerError
        self.fix = nil
    }
    
    init(_ description: String, fix: (title: String, action: UIViewController -> ())) {
        self.description = description
        self.innerError = nil
        self.fix = fix
    }
    
    convenience init(_ description: String) {
        self.init(description, innerError: nil)
    }
    
    var localizedErrorDescription: String {
        var description = self.description
        
        if let innerError = self.innerError as? PrintableError {
            description.appendContentsOf("\n\(innerError.localizedErrorDescription)")
        }
        
        return description
    }
    
    func withInnerError(error: ErrorType) -> UserError {
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
    
    static var failedToSaveVideo: UserError {
        return UserError("Failed to save video")
    }
    
    static var failedToUploadVideo: UserError {
        return UserError("Failed to upload video")
    }
    
    static var notSignedIn: UserError {
        func signIn(viewController: UIViewController) {
            HTTPClient.authenticate(fromViewController: viewController, callback: {_ in 
                // Nop
            })
        }
        
        return UserError("Not signed in", fix: (title: "Sign in", action: signIn))
    }
}

enum Try<T> {
    case Success(T)
    case Error(ErrorType)
}

