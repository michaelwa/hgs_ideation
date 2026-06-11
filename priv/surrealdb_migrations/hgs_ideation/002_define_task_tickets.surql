-- Task tickets that move through workflow FSM statuses.

DEFINE TABLE IF NOT EXISTS task_ticket SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS workflow ON TABLE task_ticket TYPE record<workflow>;
DEFINE FIELD IF NOT EXISTS status ON TABLE task_ticket TYPE record<workflow_status>;
DEFINE FIELD IF NOT EXISTS title ON TABLE task_ticket TYPE string;
DEFINE FIELD OVERWRITE data ON TABLE task_ticket TYPE object FLEXIBLE DEFAULT {};
DEFINE FIELD IF NOT EXISTS created_at ON TABLE task_ticket TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at ON TABLE task_ticket TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS task_ticket_by_workflow
  ON TABLE task_ticket
  FIELDS workflow;

DEFINE INDEX IF NOT EXISTS task_ticket_by_workflow_status
  ON TABLE task_ticket
  FIELDS workflow, status;

DEFINE TABLE IF NOT EXISTS task_status_history SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS task ON TABLE task_status_history TYPE record<task_ticket>;
DEFINE FIELD IF NOT EXISTS workflow ON TABLE task_status_history TYPE record<workflow>;
DEFINE FIELD IF NOT EXISTS from_status ON TABLE task_status_history TYPE option<record<workflow_status>>;
DEFINE FIELD IF NOT EXISTS to_status ON TABLE task_status_history TYPE record<workflow_status>;
DEFINE FIELD OVERWRITE data ON TABLE task_status_history TYPE object FLEXIBLE DEFAULT {};
DEFINE FIELD IF NOT EXISTS created_at ON TABLE task_status_history TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS task_status_history_by_task
  ON TABLE task_status_history
  FIELDS task, created_at;

DEFINE INDEX IF NOT EXISTS task_status_history_by_workflow
  ON TABLE task_status_history
  FIELDS workflow, created_at;
