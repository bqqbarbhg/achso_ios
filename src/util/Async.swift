import Foundation

func parallelAsync(functions: (((ErrorType?) -> ()) -> ())..., success: () -> (), errors: [ErrorType] -> ()) {
    var errorList: [ErrorType] = []
    var completeCount = 0
    let count = functions.count
    
    func callback(error: ErrorType?) {
        if let err = error {
            errorList.append(err)
        }
        
        if ++completeCount == count {
            if errorList.count == 0 {
                success()
            } else {
                errors(errorList)
            }
        }
    }
    
    for fn in functions {
        fn(callback)
    }
}
