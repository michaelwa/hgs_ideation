defmodule HgsIdeation.Workflows.SurrealStorageTest do
  use ExUnit.Case, async: true

  @migration_path "priv/surrealdb_migrations/hgs_ideation/001_define_workflow_graph.surql"
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

  test "demo script exercises migrations, seeding, graph loading, and Mermaid output" do
    script = File.read!(@demo_script_path)

    assert script =~ "apply_migrations(client)"
    assert script =~ "SurrealDB.query(client, File.read!(path))"
    assert script =~ "RELATE workflow_status:support_todo->can_transition_to"
    assert script =~ "SurrealRepo.load_graph(client, @workflow_slug, [])"
    assert script =~ "Graph.validate_transition("
    assert script =~ "Graph.to_mermaid(graph)"
  end
end
