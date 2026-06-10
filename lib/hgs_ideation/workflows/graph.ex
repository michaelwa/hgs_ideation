defmodule HgsIdeation.Workflows.Graph do
  @moduledoc """
  In-memory directed graph for kanban workflow state machines.

  Statuses are graph nodes. Transitions are directed graph edges. The graph is
  intentionally storage-agnostic so a later repository module can hydrate it
  from SurrealDB graph records, Postgres rows, or static fixtures.
  """

  alias HgsIdeation.Workflows.{Status, Transition}

  @enforce_keys [:id]
  defstruct [:id, statuses: %{}, transitions: [], adjacency: %{}]

  @type status_id :: Status.id()
  @type task_data :: %{optional(atom() | String.t()) => term()}

  @type t :: %__MODULE__{
          id: atom() | String.t(),
          statuses: %{status_id() => Status.t()},
          transitions: [Transition.t()],
          adjacency: %{status_id() => MapSet.t(status_id())}
        }

  @doc """
  Builds a graph from status and transition structs.
  """
  @spec new(atom() | String.t(), [Status.t() | map()], [Transition.t() | map()]) ::
          {:ok, t()} | {:error, term()}
  def new(id, statuses, transitions) do
    with {:ok, statuses_by_id} <- build_statuses(statuses),
         {:ok, transitions} <- build_transitions(transitions, statuses_by_id) do
      {:ok,
       %__MODULE__{
         id: id,
         statuses: statuses_by_id,
         transitions: transitions,
         adjacency: build_adjacency(statuses_by_id, transitions)
       }}
    end
  end

  @doc """
  Returns whether a directed edge allows movement from one status to another.
  """
  @spec allowed_transition?(t(), status_id(), status_id()) :: boolean()
  def allowed_transition?(%__MODULE__{} = graph, from, to) do
    graph.adjacency
    |> Map.get(from, MapSet.new())
    |> MapSet.member?(to)
  end

  @doc """
  Validates whether task data can move from one status to another.

  Validation checks both graph topology and required fields attached to the
  target status and the specific transition edge.
  """
  @spec validate_transition(t(), status_id(), status_id(), task_data()) :: :ok | {:error, term()}
  def validate_transition(%__MODULE__{} = graph, from, to, task_data \\ %{}) do
    with :ok <- ensure_status_exists(graph, from),
         :ok <- ensure_status_exists(graph, to),
         :ok <- ensure_allowed_transition(graph, from, to),
         {:ok, transition} <- fetch_transition(graph, from, to),
         :ok <- validate_required_fields(graph.statuses[to].required_fields, task_data),
         :ok <- validate_required_fields(transition.required_fields, task_data) do
      :ok
    end
  end

  @doc """
  Generates a Mermaid stateDiagram-v2 projection of the graph.
  """
  @spec to_mermaid(t()) :: String.t()
  def to_mermaid(%__MODULE__{} = graph) do
    status_lines =
      graph.statuses
      |> Map.values()
      |> Enum.sort_by(& &1.label)
      |> Enum.map(fn status ->
        "  state #{mermaid_id(status.id)} as #{inspect(status.label)}"
      end)

    initial_lines =
      graph.statuses
      |> Map.values()
      |> Enum.filter(& &1.initial?)
      |> Enum.sort_by(& &1.label)
      |> Enum.map(fn status -> "  [*] --> #{mermaid_id(status.id)}" end)

    transition_lines =
      graph.transitions
      |> Enum.sort_by(fn transition -> {to_string(transition.from), to_string(transition.to)} end)
      |> Enum.map(fn transition ->
        label =
          if transition.label do
            " : #{transition.label}"
          else
            ""
          end

        "  #{mermaid_id(transition.from)} --> #{mermaid_id(transition.to)}#{label}"
      end)

    terminal_lines =
      graph.statuses
      |> Map.values()
      |> Enum.filter(& &1.terminal?)
      |> Enum.sort_by(& &1.label)
      |> Enum.map(fn status -> "  #{mermaid_id(status.id)} --> [*]" end)

    Enum.join(
      ["stateDiagram-v2" | status_lines ++ initial_lines ++ transition_lines ++ terminal_lines],
      "\n"
    )
  end

  defp build_statuses(statuses) do
    statuses
    |> Enum.map(&status_struct/1)
    |> Enum.reduce_while({:ok, %{}}, fn
      %Status{id: id} = status, {:ok, acc} ->
        if Map.has_key?(acc, id) do
          {:halt, {:error, {:duplicate_status, id}}}
        else
          {:cont, {:ok, Map.put(acc, id, status)}}
        end

      invalid, _acc ->
        {:halt, {:error, {:invalid_status, invalid}}}
    end)
  end

  defp build_transitions(transitions, statuses_by_id) do
    transitions
    |> Enum.map(&transition_struct/1)
    |> Enum.reduce_while({:ok, []}, fn
      %Transition{from: from, to: to} = transition, {:ok, acc} ->
        cond do
          not Map.has_key?(statuses_by_id, from) ->
            {:halt, {:error, {:unknown_transition_status, from}}}

          not Map.has_key?(statuses_by_id, to) ->
            {:halt, {:error, {:unknown_transition_status, to}}}

          transition_key(transition) in Enum.map(acc, &transition_key/1) ->
            {:halt, {:error, {:duplicate_transition, from, to}}}

          true ->
            {:cont, {:ok, [transition | acc]}}
        end

      invalid, _acc ->
        {:halt, {:error, {:invalid_transition, invalid}}}
    end)
    |> case do
      {:ok, transitions} -> {:ok, Enum.reverse(transitions)}
      error -> error
    end
  end

  defp build_adjacency(statuses_by_id, transitions) do
    initial_adjacency =
      statuses_by_id
      |> Map.keys()
      |> Map.new(fn status_id -> {status_id, MapSet.new()} end)

    Enum.reduce(transitions, initial_adjacency, fn transition, adjacency ->
      Map.update!(adjacency, transition.from, &MapSet.put(&1, transition.to))
    end)
  end

  defp ensure_status_exists(%__MODULE__{} = graph, status_id) do
    if Map.has_key?(graph.statuses, status_id) do
      :ok
    else
      {:error, {:unknown_status, status_id}}
    end
  end

  defp ensure_allowed_transition(%__MODULE__{} = graph, from, to) do
    if allowed_transition?(graph, from, to) do
      :ok
    else
      {:error, {:transition_not_allowed, from, to}}
    end
  end

  defp fetch_transition(%__MODULE__{} = graph, from, to) do
    case Enum.find(graph.transitions, &(&1.from == from and &1.to == to)) do
      nil -> {:error, {:transition_not_found, from, to}}
      transition -> {:ok, transition}
    end
  end

  defp validate_required_fields(required_fields, task_data) do
    missing_fields =
      Enum.reject(required_fields, fn field ->
        task_data
        |> get_field(field)
        |> present?()
      end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, {:missing_required_fields, fields}}
    end
  end

  defp get_field(task_data, field) when is_atom(field) do
    Map.get(task_data, field) || Map.get(task_data, Atom.to_string(field))
  end

  defp get_field(task_data, field) when is_binary(field) do
    Map.get(task_data, field)
  end

  defp present?(value), do: value not in [nil, ""]

  defp status_struct(%Status{} = status), do: status
  defp status_struct(attrs) when is_map(attrs), do: struct(Status, attrs)
  defp status_struct(invalid), do: invalid

  defp transition_struct(%Transition{} = transition), do: transition
  defp transition_struct(attrs) when is_map(attrs), do: struct(Transition, attrs)
  defp transition_struct(invalid), do: invalid

  defp transition_key(%Transition{} = transition), do: {transition.from, transition.to}

  defp mermaid_id(status_id) do
    status_id
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_]/, "_")
    |> then(fn id ->
      if String.match?(String.first(id) || "", ~r/[A-Za-z_]/) do
        id
      else
        "state_#{id}"
      end
    end)
  end
end
