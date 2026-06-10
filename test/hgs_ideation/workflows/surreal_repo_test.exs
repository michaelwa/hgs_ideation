defmodule HgsIdeation.Workflows.SurrealRepoTest do
  use ExUnit.Case, async: true

  alias HgsIdeation.Workflows.{Graph, SurrealRepo}
  alias SurrealDB.QueryResult

  describe "workflow_record_id/1" do
    test "builds a workflow record id from a slug" do
      assert {:ok, "workflow:support"} = SurrealRepo.workflow_record_id("support")
    end

    test "rejects unsafe workflow ids" do
      assert {:error, {:invalid_workflow_id, "support; DELETE workflow"}} =
               SurrealRepo.workflow_record_id("support; DELETE workflow")
    end
  end

  describe "graph_query/0" do
    test "loads status nodes and transition edges scoped to one workflow" do
      query = SurrealRepo.graph_query("workflow:support")

      assert query =~ "FROM workflow_status"
      assert query =~ "FROM can_transition_to"
      assert query =~ "WHERE workflow = workflow:support"
      assert query =~ "ORDER BY lane_order ASC, label ASC"
    end
  end

  describe "load_graph/2" do
    test "connects and hydrates a graph from SurrealDB query rows" do
      assert {:ok, %Graph{} = graph} =
               SurrealRepo.load_graph(
                 "support",
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: fn :client, query, variables ->
                   assert query == SurrealRepo.graph_query("workflow:support")
                   assert variables == %{}

                   {:ok,
                    %QueryResult{
                      results: [status_rows(), transition_rows()],
                      statuses: ["OK", "OK"]
                    }}
                 end
               )

      assert graph.id == "workflow:support"
      assert Graph.allowed_transition?(graph, "workflow_status:todo", "workflow_status:review")
      refute Graph.allowed_transition?(graph, "workflow_status:todo", "workflow_status:done")

      assert :ok =
               Graph.validate_transition(
                 graph,
                 "workflow_status:review",
                 "workflow_status:done",
                 %{"approved_by" => "user:1", "resolution" => "Fixed"}
               )
    end

    test "returns graph validation errors from malformed SurrealDB rows" do
      assert {:error, {:unknown_transition_status, "workflow_status:missing"}} =
               SurrealRepo.load_graph(
                 "support",
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: fn :client, _query, _variables ->
                   {:ok,
                    %QueryResult{
                      results: [
                        status_rows(),
                        [
                          %{
                            "id" => "can_transition_to:bad",
                            "in" => "workflow_status:todo",
                            "out" => "workflow_status:missing"
                          }
                        ]
                      ]
                    }}
                 end
               )
    end
  end

  defp status_rows do
    [
      %{
        "id" => "workflow_status:todo",
        "label" => "Todo",
        "required_fields" => [],
        "initial" => true,
        "terminal" => false
      },
      %{
        "id" => "workflow_status:review",
        "label" => "Review",
        "required_fields" => ["approved_by"],
        "initial" => false,
        "terminal" => false
      },
      %{
        "id" => "workflow_status:done",
        "label" => "Done",
        "required_fields" => ["resolution"],
        "initial" => false,
        "terminal" => true
      }
    ]
  end

  defp transition_rows do
    [
      %{
        "id" => "can_transition_to:todo_review",
        "in" => "workflow_status:todo",
        "out" => "workflow_status:review",
        "label" => "start review",
        "required_fields" => []
      },
      %{
        "id" => "can_transition_to:review_done",
        "in" => "workflow_status:review",
        "out" => "workflow_status:done",
        "label" => "approve",
        "required_fields" => ["approved_by"]
      }
    ]
  end
end
