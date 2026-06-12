defmodule HgsIdeationWeb.WorkflowLiveTest do
  use HgsIdeationWeb.ConnCase

  import Phoenix.LiveViewTest

  alias HgsIdeation.Tasks.TaskTicket
  alias HgsIdeation.Tasks.TaskStatusHistory
  alias HgsIdeation.Workflows.Graph
  alias HgsIdeation.Workflows.{Status, Transition}

  defmodule TaskRepo do
    @moduledoc false

    def list_tasks("support", []) do
      {:ok, Agent.get(__MODULE__.Store, & &1)}
    end

    def list_status_history("support", []) do
      {:ok,
       [
         %TaskStatusHistory{
           id: "task_status_history:done",
           task_id: "task_ticket:done",
           workflow_id: "workflow:support",
           from_status_id: "review",
           to_status_id: "done",
           data: %{"approved_by" => "user:approver"},
           created_at: "2026-06-11T00:00:00Z"
         }
       ]}
    end

    def create_task("support", attrs, []) do
      task = %TaskTicket{
        id: "task_ticket:created",
        workflow_id: "workflow:support",
        status_id: attrs.status_id,
        title: attrs.title,
        data: attrs.data
      }

      Agent.update(__MODULE__.Store, &(&1 ++ [task]))

      {:ok, task}
    end

    def get_task(task_id, []) do
      case Agent.get(__MODULE__.Store, &Enum.find(&1, fn task -> task.id == task_id end)) do
        nil -> {:error, :task_not_found}
        task -> {:ok, task}
      end
    end

    def update_task_status(%TaskTicket{} = task, to_status_id, data, []) do
      moved_task = %TaskTicket{task | status_id: to_status_id, data: Map.merge(task.data, data)}

      Agent.update(__MODULE__.Store, fn tasks ->
        Enum.map(tasks, fn
          %TaskTicket{id: id} when id == task.id -> moved_task
          other -> other
        end)
      end)

      {:ok, moved_task}
    end
  end

  defmodule ErrorTaskRepo do
    @moduledoc false

    def list_tasks("support", []), do: {:error, :task_store_unavailable}
    def list_status_history("support", []), do: {:ok, []}
  end

  setup do
    previous_loader = Application.get_env(:hgs_ideation, :workflow_loader)
    previous_task_repo = Application.get_env(:hgs_ideation, :task_repo)

    start_supervised!(%{
      id: TaskRepo.Store,
      start: {Agent, :start_link, [fn -> sample_tasks() end, [name: TaskRepo.Store]]}
    })

    on_exit(fn ->
      if previous_loader do
        Application.put_env(:hgs_ideation, :workflow_loader, previous_loader)
      else
        Application.delete_env(:hgs_ideation, :workflow_loader)
      end

      if previous_task_repo do
        Application.put_env(:hgs_ideation, :task_repo, previous_task_repo)
      else
        Application.delete_env(:hgs_ideation, :task_repo)
      end
    end)

    :ok
  end

  test "renders workflow statuses, transitions, and Mermaid output", %{conn: conn} do
    Application.put_env(:hgs_ideation, :workflow_loader, fn "support", [] -> sample_graph() end)
    Application.put_env(:hgs_ideation, :task_repo, TaskRepo)

    {:ok, view, _html} = live(conn, ~p"/workflows/support")

    assert has_element?(view, "#workflow-visualization")
    assert has_element?(view, "#workflow-statuses")
    assert has_element?(view, "#workflow-status-todo")
    assert has_element?(view, "#workflow-status-review")
    assert has_element?(view, "#workflow-status-done")
    assert has_element?(view, "#workflow-task-create-todo")
    assert has_element?(view, "#workflow-status-review-tasks")
    assert has_element?(view, "#workflow-task-task_ticket-review")
    assert has_element?(view, "#workflow-task-task_ticket-done")
    assert has_element?(view, "#workflow-task-task_ticket-done-history")
    assert has_element?(view, "#workflow-history-task_status_history-done")
    assert has_element?(view, "#workflow-task-task_ticket-review-move-done-submit")
    assert has_element?(view, "#workflow-transitions")
    assert has_element?(view, "#workflow-transition-review-done")
    assert has_element?(view, "#workflow-mermaid")
  end

  test "renders a load error when the workflow cannot be loaded", %{conn: conn} do
    Application.put_env(:hgs_ideation, :workflow_loader, fn "missing", [] ->
      {:error, :not_found}
    end)

    {:ok, view, _html} = live(conn, ~p"/workflows/missing")

    assert has_element?(view, "#workflow-load-error")
  end

  test "renders the workflow when task tickets cannot be loaded", %{conn: conn} do
    Application.put_env(:hgs_ideation, :workflow_loader, fn "support", [] -> sample_graph() end)
    Application.put_env(:hgs_ideation, :task_repo, ErrorTaskRepo)

    {:ok, view, _html} = live(conn, ~p"/workflows/support")

    assert has_element?(view, "#workflow-statuses")
    assert has_element?(view, "#workflow-task-error")
  end

  test "creates a task in the initial status lane", %{conn: conn} do
    Application.put_env(:hgs_ideation, :workflow_loader, fn "support", [] -> sample_graph() end)
    Application.put_env(:hgs_ideation, :task_repo, TaskRepo)

    {:ok, view, _html} = live(conn, ~p"/workflows/support")

    view
    |> element("#workflow-task-create-todo")
    |> render_submit(%{
      "task" => %{
        "status_id" => "todo",
        "title" => "Created from board",
        "data" => %{}
      }
    })

    assert has_element?(view, "#workflow-status-todo-tasks #workflow-task-task_ticket-created")
  end

  test "moves a task through an allowed transition", %{conn: conn} do
    Application.put_env(:hgs_ideation, :workflow_loader, fn "support", [] -> sample_graph() end)
    Application.put_env(:hgs_ideation, :task_repo, TaskRepo)

    {:ok, view, _html} = live(conn, ~p"/workflows/support")

    view
    |> element("#workflow-task-task_ticket-review-move-done")
    |> render_submit(%{
      "move" => %{
        "task_id" => "task_ticket:review",
        "to_status_id" => "done",
        "data" => %{"approved_by" => "user:approver", "resolution" => "Fixed"}
      }
    })

    assert has_element?(view, "#workflow-status-done-tasks #workflow-task-task_ticket-review")
    refute has_element?(view, "#workflow-status-review-tasks #workflow-task-task_ticket-review")
  end

  test "keeps a task in place when the move is rejected", %{conn: conn} do
    Application.put_env(:hgs_ideation, :workflow_loader, fn "support", [] -> sample_graph() end)
    Application.put_env(:hgs_ideation, :task_repo, TaskRepo)

    {:ok, view, _html} = live(conn, ~p"/workflows/support")

    html =
      view
      |> element("#workflow-task-task_ticket-review-move-done")
      |> render_submit(%{
        "move" => %{
          "task_id" => "task_ticket:review",
          "to_status_id" => "done",
          "data" => %{"approved_by" => "user:approver"}
        }
      })

    assert html =~ "Missing required fields: Resolution"
    assert has_element?(view, "#workflow-status-review-tasks #workflow-task-task_ticket-review")
  end

  defp sample_graph do
    Graph.new(
      "support",
      [
        %Status{id: "todo", label: "Todo", initial?: true},
        %Status{id: "review", label: "Review", required_fields: ["reviewer_id"]},
        %Status{id: "done", label: "Done", required_fields: ["resolution"], terminal?: true}
      ],
      [
        %Transition{from: "todo", to: "review", label: "request review"},
        %Transition{
          from: "review",
          to: "done",
          label: "approve",
          required_fields: ["approved_by"]
        }
      ]
    )
  end

  defp sample_tasks do
    [
      %TaskTicket{
        id: "task_ticket:review",
        workflow_id: "workflow:support",
        status_id: "review",
        title: "Review demo task",
        data: %{"reviewer_id" => "user:reviewer"}
      },
      %TaskTicket{
        id: "task_ticket:done",
        workflow_id: "workflow:support",
        status_id: "done",
        title: "Done demo task",
        data: %{"resolution" => "Fixed"}
      }
    ]
  end
end
