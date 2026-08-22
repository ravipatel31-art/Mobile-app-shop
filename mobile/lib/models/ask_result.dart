/// Reply from POST /ask: the assistant's answer plus, when it decided a
/// change is needed, an unexecuted [PendingAction] awaiting confirmation.
class AskResult {
  final String answer;
  final String source;
  final PendingAction? pendingAction;

  const AskResult({
    required this.answer,
    required this.source,
    required this.pendingAction,
  });

  factory AskResult.fromJson(Map<String, dynamic> json) => AskResult(
        answer: (json['answer'] ?? '') as String,
        source: (json['source'] ?? 'agent') as String,
        pendingAction: json['pending_action'] == null
            ? null
            : PendingAction.fromJson(
                json['pending_action'] as Map<String, dynamic>),
      );
}

/// A proposed write-action the agent will NOT run itself — the staff member
/// must confirm it, which calls /ask/execute.
class PendingAction {
  final String action;
  final Map<String, dynamic> args;
  final String label;

  const PendingAction({
    required this.action,
    required this.args,
    required this.label,
  });

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        action: (json['action'] ?? '') as String,
        args: (json['args'] ?? {}) as Map<String, dynamic>,
        label: (json['label'] ?? '') as String,
      );
}
