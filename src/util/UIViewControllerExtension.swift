import UIKit

extension UIViewController {
    func showErrorModal(error: ErrorType, title: String, callback: (() -> ())? = nil) {
        var errorMessage = NSLocalizedString("error_unknown",
            comment: "Error title when some unknown error happened")
        
        let errorDismissButton = NSLocalizedString("error_dismiss",
            comment: "Button title for dismissing the error")
        
        if let printableError = error as? PrintableError {
            errorMessage = printableError.localizedErrorDescription
        }
        
        let alertController = UIAlertController(title: title, message: errorMessage, preferredStyle: .Alert)
        
        let dismissAction = UIAlertAction(title: errorDismissButton, style: .Default, handler: { action in
            alertController.dismissViewControllerAnimated(true) {
                callback?()
            }
        })
        
        alertController.addAction(dismissAction)
        
        if let userError = error as? UserError, fix = userError.fix {
            let fixAction = UIAlertAction(title: fix.title, style: .Default, handler: { action in
                fix.action(self, callback)
            })
            alertController.addAction(fixAction)
        }
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
}

