/*

This file defines error types and makes a framework for presenting users with helpful errors.

Any errors that implement `PrintableError` can be displayed to the user. User facing errors should be localized and if possible provided with fix actions. Errors originating from failing code logic or servers should use internal error types which don't need to be localized.

    throw UserError.failedToSaveVideo.withDebugError("Could not connect to the server")

Also defines a Rust-like `Try<T>` that contains either a result or an error.

*/

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
        return "[assertion failed: \(self.description)]"
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

enum UserPermission {
    case Camera
    case VideoLibrary
    
    var localizedName: String {
        switch self {
        case .Camera:
            return NSLocalizedString("user_permission_camera", comment: "Name for the camera permission")
        case .VideoLibrary:
            return NSLocalizedString("user_permission_video_library", comment: "Name for the camera permission")
        }
    }
}

class UserError: ErrorType, PrintableError {
    typealias FixAction = (UIViewController, (() -> ())?) -> ()
    typealias Fix = (title: String, action: FixAction)
    
    let description: String
    let innerError: ErrorType?
    let fix: Fix?

    init(_ description: String, innerError: ErrorType?, fix: Fix?) {
        self.description = description
        self.innerError = innerError
        self.fix = fix
    }
    
    init(_ description: String, fix: Fix) {
        self.description = description
        self.innerError = nil
        self.fix = fix
    }
    
    convenience init(_ description: String) {
        self.init(description, innerError: nil, fix: nil)
    }
    
    var localizedErrorDescription: String {
        var description = self.description
        
        if let innerError = self.innerError as? PrintableError {
            description.appendContentsOf("\n\(innerError.localizedErrorDescription)")
        }
        
        return description
    }
    
    func withInnerError(error: ErrorType) -> UserError {
        return UserError(self.description, innerError: error, fix: fix)
    }
    
    func withDebugError(description: String) -> UserError {
        return withInnerError(DebugError(description))
    }
    
    static func signInFixCallback(viewController: UIViewController, callback: (() -> ())?) {
        Session.authenticate(fromViewController: viewController, callback: { result in
            if let error = result.error {
                viewController.showErrorModal(error, title: NSLocalizedString("error_on_sign_in",
                    comment: "Error title when trying to sign in"))
            } else {
                videoRepository.refreshOnline()
                callback?()
            }
        })
    }
    
    static func openSettingsFixCallback(viewController: UIViewController, callback: (() -> ())?) {
        if let url = NSURL(string: UIApplicationOpenSettingsURLString) {
            UIApplication.sharedApplication().openURL(url)
        }
    }
    
    static let signInFix = Fix(title: NSLocalizedString("error_fix_sign_in",
        comment: "Error fix button to sign the user in"),
        action: UserError.signInFixCallback)
    
    static let openSettingsFix = Fix(title: NSLocalizedString("error_fix_settings",
        comment: "Error fix that opens the settings"),
        action: UserError.openSettingsFixCallback)
    
    static var invalidLayersBoxUrl: UserError {
        return UserError(NSLocalizedString("error_invalid_layers_box_url",
                comment: "Error title when the Layers Box URL is misconfigured"),
            fix: openSettingsFix)
    }
    
    static var failedToAuthenticate: UserError {
        return UserError(NSLocalizedString("error_failed_to_authenticate",
            comment: "Error title when something stopped them from authenticating"),
            fix: signInFix)
    }
    
    static var failedToSaveVideo: UserError {
        return UserError(NSLocalizedString("error_failed_to_save_video",
            comment: "Error title when something stopped them from saving a video"))
    }
    
    static var malFormedEmailAddress: UserError {
        return UserError(NSLocalizedString("error_malformed_email",
            comment: "Error title for when user inputted email is incorrect"))
    }
    
    static var failedToUploadVideo: UserError {
        return UserError(NSLocalizedString("error_failed_to_upload_video",
            comment: "Error title when something stopped them from uploading a video"))
    }
    
    static var failedToDeleteRemoteVideo: UserError {
        return UserError(NSLocalizedString("error_failed_to_delete_remote_video",
            comment: "Error title when something stopped them from deleting a remote video"))
    }
    
    static var notSignedIn: UserError {
        return UserError(NSLocalizedString("error_not_signed_in",
                comment: "Error title when the user is not signed in but would need to be"),
            fix: signInFix)
    }
    
    static func permissionsMissing(permissions: [UserPermission]) -> UserError {
        let titleBase = NSLocalizedString("error_permissions_missing", comment: "Error title when the app needs permissions which the user has not approved")
        let permissions = permissions.map { $0.localizedName }.joinWithSeparator(", ")
        
        let title = "\(titleBase) \(permissions)"
        return UserError(title, fix: openSettingsFix)
    }
}

enum Try<T> {
    case Success(T)
    case Error(ErrorType)
    
    var success: T? {
        switch self {
            case .Success(let value): return value
            case .Error: return nil
        }
    }
    
    var error: ErrorType? {
        switch self {
            case .Success: return nil
            case .Error(let error): return error
        }
    }
}

func debugError(description: String) {
    #if DEBUG
        assertionFailure(description)
    #else
        // TODO: Log error
    #endif
}

