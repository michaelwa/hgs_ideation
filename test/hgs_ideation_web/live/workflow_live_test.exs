defmodule HgsIdeationWeb.WorkflowLiveTest do
  use HgsIdeationWeb.ConnCase

  import Phoenix.LiveViewTest

  alias HgsIdeation.Workflows.Graph
  alias HgsIdeation.Workflows.{Status, Transition}

  setup do
    previous_loader = Application.get_env(:hgs_ideation, :workflow_loader)

    on_exit(fn ->
      if previous_loader do
        Application.put_env(:hgs_ideation, :workflow_loader, previous_loader)
      else
        Application.delete_env(:hgs_ideation, :workflow_loader)
      end
    end)

    :ok
  end

  test "renders workflow statuses, transitions, and Mermaid output", %{conn: conn} do
    Application.put_env(:hgs_ideation, :workflow_loader, fn "support", [] -> sample_graph() end)

    {:ok, view, _html} = live(conn, ~p"/workflows/support")

    assert has_element?(view, "#workflow-visualization")
    assert has_element?(view, "#workflow-statuses")
    assert has_element?(view, "#workflow-status-todo")
    assert has_element?(view, "#workflow-status-review")
    assert has_element?(view, "#workflow-status-done")
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
