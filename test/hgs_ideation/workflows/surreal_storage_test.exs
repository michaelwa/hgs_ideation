defmodule HgsIdeation.Workflows.SurrealStorageTest do
  use ExUnit.Case, async: true

  @migration_path "priv/surrealdb_migrations/hgs_ideation/001_define_workflow_graph.surql"
  @task_migration_path "priv/surrealdb_migrations/hgs_ideation/002_define_task_tickets.surql"
  @demo_script_path "scripts/workflow_surreal_demo.exs"

  test "workflow graph migration defines status nodes and transition edges" do
    migration = File.read!(@migration_path)

    assert migration =~ "DEFINE TABLE IF NOT EXISTS workflow SCHEMAFULL"
    assert migration =~ "DEFINE TABLE IF NOT EXISTS workflow_status SCHEMAFULL"
    assert migration =~ "DEFINE TABLE IF NOT EXISTS can_transition_to"
    assert migration =~ "TYPE RELATION"
    assert migration =~ "IN workflow_status"
    assert migration =~ "OUT workflow_status"
    assert migration =~ "DEFINE FIELD IF NOT EXISTS workflow ON TABLE workflow_status"
    assert migration =~ "DEFINE FIELD IF NOT EXISTS workflow ON TABLE can_transition_to"
    assert migration =~ "workflow_transition_unique_edge"
  end

  test "task ticket migration defines tickets and status history" do
    migration = File.read!(@task_migration_path)

    assert migration =~ "DEFINE TABLE IF NOT EXISTS task_ticket SCHEMAFULL"
    assert migration =~ "DEFINE FIELD IF NOT EXISTS workflow ON TABLE task_ticket"
    assert migration =~ "DEFINE FIELD IF NOT EXISTS status ON TABLE task_ticket"
    assert migration =~ "DEFINE FIELD OVERWRITE data ON TABLE task_ticket TYPE object FLEXIBLE"
    assert migration =~ "DEFINE TABLE IF NOT EXISTS task_status_history SCHEMAFULL"
    assert migration =~ "DEFINE FIELD IF NOT EXISTS from_status ON TABLE task_status_history"

    assert migration =~
             "DEFINE FIELD OVERWRITE data ON TABLE task_status_history TYPE object FLEXIBLE"

    assert migration =~ "task_status_history_by_task"
  end

  test "demo script exercises migrations, seeding, graph loading, and Mermaid output" do
    script = File.read!(@demo_script_path)

    assert script =~ "apply_migrations(client)"
    assert script =~ "SurrealDB.query(client, File.read!(path))"
    assert script =~ "RELATE workflow_status:support_todo->can_transition_to"
    assert script =~ "SurrealRepo.load_graph(client, @workflow_slug, [])"
    assert script =~ "Graph.validate_transition("
    assert script =~ "Tasks.move_task("
    assert script =~ "Graph.to_mermaid(graph)"
  end
end
