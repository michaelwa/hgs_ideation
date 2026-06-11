defmodule HgsIdeation.TasksTest do
  use ExUnit.Case, async: true

  alias HgsIdeation.Tasks
  alias HgsIdeation.Tasks.SurrealRepo
  alias HgsIdeation.Workflows.{Graph, Status, Transition}
  alias SurrealDB.QueryResult

  describe "move_task/4" do
    test "moves a task when the workflow graph allows the transition and data is compliant" do
      calls =
        scripted_calls([
          fn query, variables ->
            assert query == SurrealRepo.get_task_query("task_ticket:demo")
            assert variables == %{}

            {:ok, %QueryResult{results: [[task_row()]]}}
          end,
          fn query, variables ->
            assert query ==
                     SurrealRepo.update_task_status_query(
                       "task_ticket:demo",
                       "workflow:support",
                       "workflow_status:support_review",
                       "workflow_status:support_done"
                     )

            assert variables.data["approved_by"] == "user:demo"
            assert variables.data["resolution"] == "Fixed"
            assert variables.data["reviewer_id"] == "user:reviewer"

            {:ok,
             %QueryResult{
               results: [
                 [
                   task_row(%{
                     "status" => "workflow_status:support_done",
                     "data" => variables.data
                   })
                 ],
                 [%{"id" => "task_status_history:one"}]
               ]
             }}
          end
        ])

      assert {:ok, moved_task} =
               Tasks.move_task(
                 "task_ticket:demo",
                 "workflow_status:support_done",
                 %{"approved_by" => "user:demo", "resolution" => "Fixed"},
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: query_fun(calls),
                 workflow_loader: fn "support", [] -> sample_graph() end
               )

      assert moved_task.status_id == "workflow_status:support_done"
      assert_no_remaining_calls(calls)
    end

    test "rejects invalid transitions before updating task storage" do
      calls =
        scripted_calls([
          fn query, variables ->
            assert query == SurrealRepo.get_task_query("task_ticket:demo")
            assert variables == %{}

            {:ok, %QueryResult{results: [[task_row()]]}}
          end
        ])

      assert {:error,
              {:transition_not_allowed, "workflow_status:support_review",
               "workflow_status:support_todo"}} =
               Tasks.move_task(
                 "task_ticket:demo",
                 "workflow_status:support_todo",
                 %{},
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: query_fun(calls),
                 workflow_loader: fn "support", [] -> sample_graph() end
               )

      assert_no_remaining_calls(calls)
    end

    test "rejects missing compliance fields before updating task storage" do
      calls =
        scripted_calls([
          fn query, variables ->
            assert query == SurrealRepo.get_task_query("task_ticket:demo")
            assert variables == %{}

            {:ok, %QueryResult{results: [[task_row()]]}}
          end
        ])

      assert {:error, {:missing_required_fields, ["resolution"]}} =
               Tasks.move_task(
                 "task_ticket:demo",
                 "workflow_status:support_done",
                 %{"approved_by" => "user:demo"},
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: query_fun(calls),
                 workflow_loader: fn "support", [] -> sample_graph() end
               )

      assert_no_remaining_calls(calls)
    end
  end

  defp sample_graph do
    Graph.new(
      "workflow:support",
      [
        %Status{id: "workflow_status:support_review", label: "Review"},
        %Status{
          id: "workflow_status:support_done",
          label: "Done",
          required_fields: ["resolution"]
        },
        %Status{id: "workflow_status:support_todo", label: "Todo"}
      ],
      [
        %Transition{
          from: "workflow_status:support_review",
          to: "workflow_status:support_done",
          label: "approve",
          required_fields: ["approved_by"]
        }
      ]
    )
  end

  defp task_row(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "task_ticket:demo",
        "workflow" => "workflow:support",
        "status" => "workflow_status:support_review",
        "title" => "Demo task",
        "data" => %{"reviewer_id" => "user:reviewer"},
        "created_at" => "2026-06-11T00:00:00Z",
        "updated_at" => "2026-06-11T00:00:00Z"
      },
      overrides
    )
  end

  defp scripted_calls(callbacks) do
    {:ok, agent} = Agent.start_link(fn -> callbacks end)
    agent
  end

  defp query_fun(agent) do
    fn :client, query, variables ->
      callback =
        Agent.get_and_update(agent, fn
          [callback | rest] -> {callback, rest}
          [] -> flunk("unexpected query: #{query}")
        end)

      callback.(query, variables)
    end
  end

  defp assert_no_remaining_calls(agent) do
    assert Agent.get(agent, & &1) == []
  end
end
