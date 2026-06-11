defmodule HgsIdeationWeb.WorkflowLiveTest do
  use HgsIdeationWeb.ConnCase

  import Phoenix.LiveViewTest

  alias HgsIdeation.Tasks.TaskTicket
  alias HgsIdeation.Workflows.Graph
  alias HgsIdeation.Workflows.{Status, Transition}

  defmodule TaskRepo do
    @moduledoc false

    def list_tasks("support", []) do
      {:ok,
       [
         %TaskTicket{
           id: "task_ticket:review",
           workflow_id: "workflow:support",
           status_id: :review,
           title: "Review demo task",
           data: %{"reviewer_id" => "user:reviewer"}
         },
         %TaskTicket{
           id: "task_ticket:done",
           workflow_id: "workflow:support",
           status_id: :done,
           title: "Done demo task",
           data: %{"resolution" => "Fixed"}
         }
       ]}
    end
  end

  defmodule ErrorTaskRepo do
    @moduledoc false

    def list_tasks("support", []), do: {:error, :task_store_unavailable}
  end

  setup do
    previous_loader = Application.get_env(:hgs_ideation, :workflow_loader)
    previous_task_repo = Application.get_env(:hgs_ideation, :task_repo)

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
    assert has_element?(view, "#workflow-status-review-tasks")
    assert has_element?(view, "#workflow-task-task_ticket-review")
    assert has_element?(view, "#workflow-task-task_ticket-done")
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

  defp sample_graph do
    Graph.new(
      :support,
      [
        %Status{id: :todo, label: "Todo", initial?: true},
        %Status{id: :review, label: "Review", required_fields: [:reviewer_id]},
        %Status{id: :done, label: "Done", required_fields: [:resolution], terminal?: true}
      ],
      [
        %Transition{from: :todo, to: :review, label: "request review"},
        %Transition{from: :review, to: :done, label: "approve", required_fields: [:approved_by]}
      ]
    )
  end
end
