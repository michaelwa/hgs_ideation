defmodule HgsIdeation.Workflows do
  @moduledoc """
  Public context API for workflow FSM graphs.

  This module is the boundary Phoenix/UI code should call. The graph module
  owns pure FSM behavior, while repository modules own persistence details.
  """

  alias HgsIdeation.Workflows.{Graph, SurrealRepo}

  @type workflow_id :: SurrealRepo.workflow_id()
  @type status_id :: Graph.status_id()
  @type task_data :: Graph.task_data()

  @doc """
  Loads a workflow graph from the configured repository.
  """
  @spec load_graph(workflow_id(), keyword()) :: {:ok, Graph.t()} | {:error, term()}
  def load_graph(workflow_id, opts \\ []) when is_binary(workflow_id) and is_list(opts) do
    {loader, repo_opts} = loader(opts)

    loader.(workflow_id, repo_opts)
  end

  @doc """
  Returns whether a loaded graph allows movement from one status to another.
  """
  @spec allowed_transition?(Graph.t(), status_id(), status_id()) :: boolean()
  def allowed_transition?(%Graph{} = graph, from, to) do
    Graph.allowed_transition?(graph, from, to)
  end

  @doc """
  Validates whether task data can move through a loaded graph transition.
  """
  @spec validate_transition(Graph.t(), status_id(), status_id(), task_data()) ::
          :ok | {:error, term()}
  def validate_transition(%Graph{} = graph, from, to, task_data \\ %{}) do
    Graph.validate_transition(graph, from, to, task_data)
  end

  @doc """
  Loads a workflow graph and validates a transition against it.
  """
  @spec validate_workflow_transition(
          workflow_id(),
          status_id(),
          status_id(),
          task_data(),
          keyword()
        ) :: :ok | {:error, term()}
  def validate_workflow_transition(workflow_id, from, to, task_data \\ %{}, opts \\ [])
      when is_binary(workflow_id) and is_list(opts) do
    with {:ok, graph} <- load_graph(workflow_id, opts) do
      validate_transition(graph, from, to, task_data)
    end
  end

  @doc """
  Generates Mermaid stateDiagram-v2 text from a loaded graph.
  """
  @spec to_mermaid(Graph.t()) :: String.t()
  def to_mermaid(%Graph{} = graph) do
    Graph.to_mermaid(graph)
  end

  @doc """
  Loads a workflow graph and generates Mermaid stateDiagram-v2 text.
  """
  @spec workflow_to_mermaid(workflow_id(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def workflow_to_mermaid(workflow_id, opts \\ [])
      when is_binary(workflow_id) and is_list(opts) do
    with {:ok, graph} <- load_graph(workflow_id, opts) do
      {:ok, to_mermaid(graph)}
    end
  end

  @doc """
  Returns loaded graph statuses sorted for lane display.
  """
  @spec list_statuses(Graph.t()) :: [HgsIdeation.Workflows.Status.t()]
  def list_statuses(%Graph{} = graph) do
    graph.statuses
    |> Map.values()
    |> Enum.sort_by(& &1.label)
  end

  @doc """
  Returns loaded graph transitions in stable order.
  """
  @spec list_transitions(Graph.t()) :: [HgsIdeation.Workflows.Transition.t()]
  def list_transitions(%Graph{} = graph) do
    Enum.sort_by(graph.transitions, fn transition ->
      {to_string(transition.from), to_string(transition.to), transition.label || ""}
    end)
  end

  defp loader(opts) do
    loader =
      Keyword.get_lazy(opts, :loader, fn ->
        Application.get_env(:hgs_ideation, :workflow_loader, &SurrealRepo.load_graph/2)
      end)

    repo_opts = Keyword.delete(opts, :loader)

    {loader, repo_opts}
  end
end
