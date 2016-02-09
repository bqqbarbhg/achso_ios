/*

Simple task graph implementaiton. Tasks can dynamically spawn subtasks and defer to them when completed.

Tasks need to be completed or failed explcitly, which allows using asynchronous APIs inside the task processing.

    class GetAllThingsTask: Task {
        func run() {
            getAllThingsAsync() { tryThings in
                guard let things = tryThings else { self.fail(tryThings.error) }

                for thing in things {
                    self.addSubtask(GetOneThingTask(thing))
                }

                self.done()
            }
        }
    }

*/

import Foundation

class Task {
    
    enum State {
    case WaitingToStart
    case WaitingForSupertasks
    case Running
    case WaitingForSubtasks
    case Finished
    }
    
    var subtasks: [Task] = []
    var supertasks: [Task] = []
    
    var subtasksCompletedCount: Int = 0
    var supertasksCompletedCount: Int = 0
    
    var completionHandler: (() -> ())?
    
    var state: State = .WaitingToStart
    
    var error: ErrorType? = nil
    
    var errors: [ErrorType] = []
    
    func addSubtask(task: Task) {
        self.subtasks.append(task)
        task.supertasks.append(self)
    }
    
    func start() {
        if self.state != .WaitingToStart { return }
        
        if self.supertasksCompletedCount == self.supertasks.count {
            self.allSupetasksHaveCompleted()
        } else {
            self.state = .WaitingForSupertasks
        }
    }
    
    func supertaskDidComplete() {
        if self.state != .WaitingForSupertasks { return }
        
        self.supertasksCompletedCount++
        
        if self.supertasksCompletedCount == self.supertasks.count {
            self.allSupetasksHaveCompleted()
        }
    }
    
    func allSupetasksHaveCompleted() {
        self.state = .Running
        self.run()
    }
    
    func subtaskDidComplete() {
        if self.state != .WaitingForSubtasks { return }
        
        self.subtasksCompletedCount++
        
        if self.subtasksCompletedCount == self.subtasks.count {
            self.allSubtasksHaveCompleted()
        }
    }
    
    func allSubtasksHaveCompleted() {
        self.state = .Finished
        
        let base: [ErrorType] = {
            switch self.error {
            case .Some(let error): return [error]
            case .None: return []
            }
        }()
        self.errors = subtasks.reduce(base) { $0 + $1.errors }
        
        for supertask in self.supertasks {
            supertask.subtaskDidComplete()
        }
        
        self.completionHandler?()
    }
    
    func run() {
        self.fail(DebugError("Trying to run an empty task"))
    }
    
    func fail(error: ErrorType) {
        self.error = error
        self.done()
    }
    
    func done() {
        if self.subtasksCompletedCount == self.subtasks.count {
            self.allSubtasksHaveCompleted()
        } else {
            self.state = .WaitingForSubtasks
        }
        
        for subtask in self.subtasks {
            subtask.supertaskDidComplete()
        }
    }
}

