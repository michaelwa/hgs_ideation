-- Workflow FSM graph storage for HgsIdeation.
--
-- Statuses are stored as workflow_status records.
-- Allowed transitions are stored as can_transition_to relation edges.

DEFINE TABLE IF NOT EXISTS workflow SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS slug ON TABLE workflow TYPE string;
DEFINE FIELD IF NOT EXISTS name ON TABLE workflow TYPE string;
DEFINE FIELD IF NOT EXISTS description ON TABLE workflow TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at ON TABLE workflow TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at ON TABLE workflow TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS workflow_unique_slug
  ON TABLE workflow
  FIELDS slug
  UNIQUE;

DEFINE TABLE IF NOT EXISTS workflow_status SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS workflow ON TABLE workflow_status TYPE record<workflow>;
DEFINE FIELD IF NOT EXISTS label ON TABLE workflow_status TYPE string;
DEFINE FIELD IF NOT EXISTS description ON TABLE workflow_status TYPE option<string>;
DEFINE FIELD IF NOT EXISTS required_fields ON TABLE workflow_status TYPE array<string> DEFAULT [];
DEFINE FIELD IF NOT EXISTS initial ON TABLE workflow_status TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS terminal ON TABLE workflow_status TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS lane_order ON TABLE workflow_status TYPE int;
DEFINE FIELD IF NOT EXISTS created_at ON TABLE workflow_status TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at ON TABLE workflow_status TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS workflow_status_by_workflow
  ON TABLE workflow_status
  FIELDS workflow;

DEFINE INDEX IF NOT EXISTS workflow_status_unique_lane_order
  ON TABLE workflow_status
  FIELDS workflow, lane_order
  UNIQUE;

DEFINE TABLE IF NOT EXISTS can_transition_to
  TYPE RELATION
  IN workflow_status
  OUT workflow_status
  SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS workflow ON TABLE can_transition_to TYPE record<workflow>;
DEFINE FIELD IF NOT EXISTS label ON TABLE can_transition_to TYPE option<string>;
DEFINE FIELD IF NOT EXISTS required_fields ON TABLE can_transition_to TYPE array<string> DEFAULT [];
DEFINE FIELD IF NOT EXISTS created_at ON TABLE can_transition_to TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at ON TABLE can_transition_to TYPE datetime DEFAULT time::now();

DEFINE INDEX IF NOT EXISTS workflow_transition_by_workflow
  ON TABLE can_transition_to
  FIELDS workflow;

DEFINE INDEX IF NOT EXISTS workflow_transition_unique_edge
  ON TABLE can_transition_to
  FIELDS workflow, in, out
  UNIQUE;
