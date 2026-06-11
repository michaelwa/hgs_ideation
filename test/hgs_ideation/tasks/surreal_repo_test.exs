defmodule HgsIdeation.Tasks.SurrealRepoTest do
  use ExUnit.Case, async: true

  alias HgsIdeation.Tasks.{SurrealRepo, TaskTicket}
  alias SurrealDB.QueryResult

  describe "list_tasks/2" do
    test "loads task tickets scoped to a workflow record" do
      assert {:ok, [%TaskTicket{} = task]} =
               SurrealRepo.list_tasks(
                 "support",
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: fn :client, query, variables ->
                   assert query == SurrealRepo.list_tasks_query("workflow:support")
                   assert variables == %{}

                   {:ok, %QueryResult{results: [[task_row()]]}}
                 end
               )

      assert task.id == "task_ticket:demo"
      assert task.workflow_id == "workflow:support"
      assert task.status_id == "workflow_status:support_review"
      assert task.title == "Demo task"
      assert task.data == %{"reviewer_id" => "user:reviewer"}
    end
  end

  describe "create_task/3" do
    test "creates a task with workflow and status record ids" do
      assert {:ok, %TaskTicket{} = task} =
               SurrealRepo.create_task(
                 "support",
                 %{
                   title: "New task",
                   status_id: "workflow_status:support_todo",
                   data: %{"priority" => "normal"}
                 },
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: fn :client, query, variables ->
                   assert query ==
                            SurrealRepo.create_task_query(
                              "workflow:support",
                              "workflow_status:support_todo"
                            )

                   assert variables == %{title: "New task", data: %{"priority" => "normal"}}

                   {:ok,
                    %QueryResult{
                      results: [
                        [
                          task_row(%{
                            "title" => "New task",
                            "status" => "workflow_status:support_todo",
                            "data" => %{"priority" => "normal"}
                          })
                        ]
                      ]
                    }}
                 end
               )

      assert task.title == "New task"
      assert task.status_id == "workflow_status:support_todo"
    end

    test "rejects unsafe status record ids" do
      assert {:error, {:invalid_record_id, "workflow_status:support;DELETE", "workflow_status"}} =
               SurrealRepo.create_task(
                 "support",
                 %{title: "Bad task", status_id: "workflow_status:support;DELETE"},
                 connect_fun: fn -> {:ok, :client} end
               )
    end
  end

  describe "update_task_status/4" do
    test "updates a task and creates history" do
      task = %TaskTicket{
        id: "task_ticket:demo",
        workflow_id: "workflow:support",
        status_id: "workflow_status:support_review",
        title: "Demo task",
        data: %{"reviewer_id" => "user:reviewer"}
      }

      assert {:ok, %TaskTicket{} = moved_task} =
               SurrealRepo.update_task_status(
                 task,
                 "workflow_status:support_done",
                 %{"approved_by" => "user:demo", "resolution" => "Fixed"},
                 connect_fun: fn -> {:ok, :client} end,
                 query_fun: fn :client, query, variables ->
                   assert query ==
                            SurrealRepo.update_task_status_query(
                              "task_ticket:demo",
                              "workflow:support",
                              "workflow_status:support_review",
                              "workflow_status:support_done"
                            )

                   assert variables == %{
                            data: %{
                              "reviewer_id" => "user:reviewer",
                              "approved_by" => "user:demo",
                              "resolution" => "Fixed"
                            }
                          }

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
               )

      assert moved_task.status_id == "workflow_status:support_done"
      assert moved_task.data["approved_by"] == "user:demo"
    end
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
end
