defmodule HgsIdeation.WorkflowsTest do
  use ExUnit.Case, async: true

  alias HgsIdeation.Workflows
  alias HgsIdeation.Workflows.{Graph, Status, Transition}

  describe "load_graph/2" do
    test "loads a graph through an injected loader" do
      loader = fn workflow_id, opts ->
        assert workflow_id == "support"
        assert opts == [client: :demo]

        sample_graph()
      end

      assert {:ok, %Graph{id: :support}} =
               Workflows.load_graph("support", loader: loader, client: :demo)
    end

    test "returns loader errors" do
      loader = fn "missing", [] -> {:error, :not_found} end

      assert {:error, :not_found} = Workflows.load_graph("missing", loader: loader)
    end
  end

  describe "transition validation" do
    test "checks graph transitions without exposing Graph to callers" do
      {:ok, graph} = sample_graph()

      assert Workflows.allowed_transition?(graph, :todo, :review)
      refute Workflows.allowed_transition?(graph, :todo, :done)

      assert :ok =
               Workflows.validate_transition(graph, :review, :done, %{
                 approved_by: "user:1",
                 resolution: "Fixed"
               })

      assert {:error, {:missing_required_fields, [:approved_by]}} =
               Workflows.validate_transition(graph, :review, :done, %{resolution: "Fixed"})
    end

    test "loads a graph before validating a workflow transition" do
      loader = fn "support", [] -> sample_graph() end

      assert :ok =
               Workflows.validate_workflow_transition(
                 "support",
                 :review,
                 :done,
                 %{approved_by: "user:1", resolution: "Fixed"},
                 loader: loader
               )
    end
  end

  describe "diagram and list helpers" do
    test "generates Mermaid text for a loaded graph" do
      {:ok, graph} = sample_graph()

      assert Workflows.to_mermaid(graph) =~ "stateDiagram-v2"
      assert Workflows.to_mermaid(graph) =~ "review --> done : approve"
    end

    test "loads a workflow before generating Mermaid text" do
      loader = fn "support", [] -> sample_graph() end

      assert {:ok, mermaid} = Workflows.workflow_to_mermaid("support", loader: loader)
      assert mermaid =~ "[*] --> todo"
    end

    test "returns statuses and transitions in stable display order" do
      {:ok, graph} = sample_graph()

      assert Enum.map(Workflows.list_statuses(graph), & &1.label) == ["Done", "Review", "Todo"]

      assert Enum.map(Workflows.list_transitions(graph), &{&1.from, &1.to}) == [
               {:review, :done},
               {:todo, :review}
             ]
    end
  end

  defp sample_graph do
    Graph.new(
      :support,
      [
        %Status{id: :todo, label: "Todo", initial?: true},
        %Status{id: :review, label: "Review", required_fields: [:approved_by]},
        %Status{id: :done, label: "Done", required_fields: [:resolution], terminal?: true}
      ],
      [
        %Transition{from: :todo, to: :review, label: "request review"},
        %Transition{from: :review, to: :done, label: "approve", required_fields: [:approved_by]}
      ]
    )
  end
end
