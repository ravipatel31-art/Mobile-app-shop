import Foundation

/// Reply from POST /ask: the answer plus, when a change is needed, an
/// unexecuted PendingAction awaiting confirmation.
struct AskResult {
    let answer: String
    let source: String
    let pendingAction: PendingAction?

    init(answer: String, source: String, pendingAction: PendingAction?) {
        self.answer = answer
        self.source = source
        self.pendingAction = pendingAction
    }
    init(json: JSON) {
        self.answer = json.string("answer")
        self.source = json.string("source", "agent")
        self.pendingAction = json["pending_action"].flatMap {
            ($0 as? JSON).map(PendingAction.init(json:))
        }
    }
}

/// A proposed write-action the agent will NOT run itself — the user must
/// confirm it, which calls /ask/execute.
struct PendingAction {
    let action: String
    let args: JSON
    let label: String

    init(action: String, args: JSON, label: String) {
        self.action = action
        self.args = args
        self.label = label
    }
    init(json: JSON) {
        self.action = json.string("action")
        self.args = json.json("args")
        self.label = json.string("label")
    }
}
