defmodule HgsIdeation.Workflows.GraphTest do
  use ExUnit.Case, async: true

  alias HgsIdeation.Workflows.{Graph, Status, Transition}

  describe "new/3" do
    test "builds an adjacency map from statuses and transitions" do
      assert {:ok, graph} = Graph.new(:support, statuses(), transitions())

      assert Graph.allowed_transition?(graph, :todo, :in_progress)
      assert Graph.allowed_transition?(graph, :in_progress, :review)
      refute Graph.allowed_transition?(graph, :todo, :done)
    end

    test "rejects duplicate statuses" do
      statuses = [
        %Status{id: :todo, label: "Todo"},
        %Status{id: :todo, label: "Duplicate Todo"}
      ]

      assert {:error, {:duplicate_status, :todo}} = Graph.new(:support, statuses, [])
    end

    test "rejects transitions that reference unknown statuses" do
      assert {:error, {:unknown_transition_status, :missing}} =
               Graph.new(:support, statuses(), [%Transition{from: :todo, to: :missing}])
    end
  end

  describe "validate_transition/4" do
    setup do
      {:ok, graph} = Graph.new(:support, statuses(), transitions())

      %{graph: graph}
    end

    test "allows a valid transition when compliance fields are present", %{graph: graph} do
      task_data = %{
        assignee_id: "user:1",
        reviewer_id: "user:2",
        review_notes: "Ready for review"
      }

      assert :ok = Graph.validate_transition(graph, :in_progress, :review, task_data)
    end

    test "rejects a transition without a directed edge", %{graph: graph} do
      assert {:error, {:transition_not_allowed, :todo, :done}} =
               Graph.validate_transition(graph, :todo, :done, %{})
    end

    test "rejects a transition when target status requirements are missing", %{graph: graph} do
      assert {:error, {:missing_required_fields, [:assignee_id]}} =
               Graph.validate_transition(graph, :todo, :in_progress, %{})
    end

    test "rejects a transition when edge-specific requirements are missing", %{graph: graph} do
      task_data = %{assignee_id: "user:1", reviewer_id: "user:2"}

      assert {:error, {:missing_required_fields, [:review_notes]}} =
               Graph.validate_transition(graph, :in_progress, :review, task_data)
    end

    test "accepts string task data keys for atom field requirements", %{graph: graph} do
      task_data = %{
        "assignee_id" => "user:1",
        "reviewer_id" => "user:2",
        "review_notes" => "Looks good"
      }

      assert :ok = Graph.validate_transition(graph, :in_progress, :review, task_data)
    end
  end

  describe "to_mermaid/1" do
    test "renders a deterministic stateDiagram-v2 projection" do
      assert {:ok, graph} = Graph.new(:support, statuses(), transitions())

      assert Graph.to_mermaid(graph) == """
             stateDiagram-v2
               state done as "Done"
               state in_progress as "In Progress"
               state review as "Review"
               state todo as "Todo"
               [*] --> todo
               in_progress --> review : request review
               review --> done : approve
               review --> in_progress : request changes
               todo --> in_progress
               done --> [*]\
             """
    end
  end

  defp statuses do
    [
      %Status{id: :todo, label: "Todo", initial?: true},
      %Status{id: :in_progress, label: "In Progress", required_fields: [:assignee_id]},
      %Status{id: :review, label: "Review", required_fields: [:reviewer_id]},
      %Status{id: :done, label: "Done", required_fields: [:completed_at], terminal?: true}
    ]
  end

  defp transitions do
    [
      %Transition{from: :todo, to: :in_progress},
      %Transition{
        from: :in_progress,
        to: :review,
        label: "request review",
        required_fields: [:review_notes]
      },
      %Transition{from: :review, to: :in_progress, label: "request changes"},
      %Transition{from: :review, to: :done, label: "approve"}
    ]
  end
end
