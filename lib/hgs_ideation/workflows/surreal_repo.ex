defmodule HgsIdeation.Workflows.SurrealRepo do
  @moduledoc """
  Loads workflow FSM graphs from SurrealDB status records and graph edges.

  The repository expects workflow statuses to be stored in `workflow_status`
  records scoped by a `workflow` field, and transitions to be stored as
  `can_transition_to` edge records with the same `workflow` field.
  """

  alias HgsIdeation.Workflows.{Graph, Status, Transition}
  alias SurrealDB.QueryResult

  @status_table "workflow_status"
  @transition_edge "can_transition_to"

  @type workflow_id :: String.t()

  @doc """
  Connects with the configured SurrealDB client and loads a workflow graph.
  """
  @spec load_graph(workflow_id(), keyword()) :: {:ok, Graph.t()} | {:error, term()}
  def load_graph(workflow_id, opts \\ []) when is_binary(workflow_id) and is_list(opts) do
    connect_fun = Keyword.get(opts, :connect_fun, &SurrealDB.connect/0)

    with {:ok, client} <- connect_fun.() do
      load_graph(client, workflow_id, opts)
    end
  end

  @doc """
  Loads a workflow graph with an existing SurrealDB client.
  """
  @spec load_graph(term(), workflow_id(), keyword()) :: {:ok, Graph.t()} | {:error, term()}
  def load_graph(client, workflow_id, opts)
      when is_binary(workflow_id) and is_list(opts) do
    query_fun = Keyword.get(opts, :query_fun, &SurrealDB.query/3)

    with {:ok, workflow_record_id} <- workflow_record_id(workflow_id),
         {:ok, %QueryResult{results: [status_rows, transition_rows | _]}} <-
           query_fun.(client, graph_query(workflow_record_id), %{}) do
      statuses = Enum.map(status_rows, &to_status/1)
      transitions = Enum.map(transition_rows, &to_transition/1)

      Graph.new(workflow_record_id, statuses, transitions)
    end
  end

  @doc """
  Returns the SurrealQL used to hydrate a graph.

  This is public so tests and future migration notes can keep the expected
  storage shape explicit.
  """
  @spec graph_query() :: String.t()
  def graph_query do
    graph_query("$workflow")
  end

  @doc """
  Returns the SurrealQL used to hydrate a graph for a validated workflow record id.
  """
  @spec graph_query(String.t()) :: String.t()
  def graph_query(workflow_record_id) when is_binary(workflow_record_id) do
    """
    SELECT
      id,
      label,
      description,
      required_fields,
      initial,
      terminal,
      lane_order
    FROM #{@status_table}
    WHERE workflow = #{workflow_record_id}
    ORDER BY lane_order ASC, label ASC;

    SELECT
      id,
      in,
      out,
      label,
      required_fields
    FROM #{@transition_edge}
    WHERE workflow = #{workflow_record_id}
    ORDER BY label ASC, id ASC;
    """
  end

  @doc """
  Builds a SurrealDB record id for a workflow slug.
  """
  @spec workflow_record_id(String.t()) :: {:ok, String.t()} | {:error, term()}
  def workflow_record_id(workflow_id) when is_binary(workflow_id) do
    workflow_id = String.trim(workflow_id)

    if Regex.match?(~r/\A[A-Za-z0-9_:-]+\z/, workflow_id) do
      {:ok, "workflow:#{workflow_id}"}
    else
      {:error, {:invalid_workflow_id, workflow_id}}
    end
  end

  defp to_status(row) when is_map(row) do
    %Status{
      id: record_id(row["id"]),
      label: row["label"],
      description: row["description"],
      required_fields: row["required_fields"] || [],
      initial?: truthy?(row["initial"]),
      terminal?: truthy?(row["terminal"])
    }
  end

  defp to_transition(row) when is_map(row) do
    %Transition{
      from: record_id(row["in"] || row["from"]),
      to: record_id(row["out"] || row["to"]),
      label: row["label"],
      required_fields: row["required_fields"] || []
    }
  end

  defp record_id(%{"id" => id}), do: record_id(id)
  defp record_id(%{id: id}), do: record_id(id)
  defp record_id(id), do: to_string(id)

  defp truthy?(value), do: value in [true, "true", 1]
end
