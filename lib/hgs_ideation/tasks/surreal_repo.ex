defmodule HgsIdeation.Tasks.SurrealRepo do
  @moduledoc """
  Persists task tickets in SurrealDB.
  """

  alias HgsIdeation.Tasks.{TaskStatusHistory, TaskTicket}
  alias HgsIdeation.Workflows.SurrealRepo, as: WorkflowRepo
  alias SurrealDB.QueryResult

  @type task_id :: TaskTicket.id()
  @type workflow_id :: WorkflowRepo.workflow_id()

  @doc """
  Connects with the configured SurrealDB client and lists workflow status history.
  """
  @spec list_status_history(workflow_id(), keyword()) ::
          {:ok, [TaskStatusHistory.t()]} | {:error, term()}
  def list_status_history(workflow_id, opts \\ [])
      when is_binary(workflow_id) and is_list(opts) do
    with {:ok, client} <- connect(opts) do
      list_status_history(client, workflow_id, opts)
    end
  end

  @doc """
  Lists workflow status history with an existing SurrealDB client.
  """
  @spec list_status_history(term(), workflow_id(), keyword()) ::
          {:ok, [TaskStatusHistory.t()]} | {:error, term()}
  def list_status_history(client, workflow_id, opts)
      when is_binary(workflow_id) and is_list(opts) do
    query_fun = Keyword.get(opts, :query_fun, &SurrealDB.query/3)

    with {:ok, workflow_record_id} <- WorkflowRepo.workflow_record_id(workflow_id),
         {:ok, %QueryResult{results: [rows | _]}} <-
           query_fun.(client, list_status_history_query(workflow_record_id), %{}) do
      {:ok, Enum.map(rows || [], &to_status_history/1)}
    end
  end

  @doc """
  Connects with the configured SurrealDB client and lists workflow tasks.
  """
  @spec list_tasks(workflow_id(), keyword()) :: {:ok, [TaskTicket.t()]} | {:error, term()}
  def list_tasks(workflow_id, opts \\ []) when is_binary(workflow_id) and is_list(opts) do
    with {:ok, client} <- connect(opts) do
      list_tasks(client, workflow_id, opts)
    end
  end

  @doc """
  Lists workflow tasks with an existing SurrealDB client.
  """
  @spec list_tasks(term(), workflow_id(), keyword()) :: {:ok, [TaskTicket.t()]} | {:error, term()}
  def list_tasks(client, workflow_id, opts) when is_binary(workflow_id) and is_list(opts) do
    query_fun = Keyword.get(opts, :query_fun, &SurrealDB.query/3)

    with {:ok, workflow_record_id} <- WorkflowRepo.workflow_record_id(workflow_id),
         {:ok, %QueryResult{results: [rows | _]}} <-
           query_fun.(client, list_tasks_query(workflow_record_id), %{}) do
      {:ok, Enum.map(rows || [], &to_task/1)}
    end
  end

  @doc """
  Creates a task ticket in a workflow status.
  """
  @spec create_task(workflow_id(), map(), keyword()) :: {:ok, TaskTicket.t()} | {:error, term()}
  def create_task(workflow_id, attrs, opts \\ [])
      when is_binary(workflow_id) and is_map(attrs) and is_list(opts) do
    with {:ok, client} <- connect(opts) do
      create_task(client, workflow_id, attrs, opts)
    end
  end

  @doc """
  Creates a task ticket with an existing SurrealDB client.
  """
  @spec create_task(term(), workflow_id(), map(), keyword()) ::
          {:ok, TaskTicket.t()} | {:error, term()}
  def create_task(client, workflow_id, attrs, opts)
      when is_binary(workflow_id) and is_map(attrs) and is_list(opts) do
    query_fun = Keyword.get(opts, :query_fun, &SurrealDB.query/3)

    with {:ok, workflow_record_id} <- WorkflowRepo.workflow_record_id(workflow_id),
         {:ok, status_id} <- required_attr(attrs, :status_id),
         {:ok, status_record_id} <- validate_record_id(status_id, "workflow_status"),
         {:ok, title} <- required_attr(attrs, :title),
         {:ok, %QueryResult{results: [rows | _]}} <-
           query_fun.(client, create_task_query(workflow_record_id, status_record_id), %{
             title: title,
             data: Map.get(attrs, :data, Map.get(attrs, "data", %{}))
           }),
         {:ok, task} <- one_task(rows) do
      {:ok, task}
    end
  end

  @doc """
  Loads a task ticket by record id.
  """
  @spec get_task(task_id(), keyword()) :: {:ok, TaskTicket.t()} | {:error, term()}
  def get_task(task_id, opts \\ []) when is_binary(task_id) and is_list(opts) do
    with {:ok, client} <- connect(opts) do
      get_task(client, task_id, opts)
    end
  end

  @doc """
  Loads a task ticket by record id with an existing SurrealDB client.
  """
  @spec get_task(term(), task_id(), keyword()) :: {:ok, TaskTicket.t()} | {:error, term()}
  def get_task(client, task_id, opts) when is_binary(task_id) and is_list(opts) do
    query_fun = Keyword.get(opts, :query_fun, &SurrealDB.query/3)

    with {:ok, task_record_id} <- validate_record_id(task_id, "task_ticket"),
         {:ok, %QueryResult{results: [rows | _]}} <-
           query_fun.(client, get_task_query(task_record_id), %{}),
         {:ok, task} <- one_task(rows) do
      {:ok, task}
    end
  end

  @doc """
  Updates a task status and records transition history.
  """
  @spec update_task_status(TaskTicket.t(), String.t(), map(), keyword()) ::
          {:ok, TaskTicket.t()} | {:error, term()}
  def update_task_status(%TaskTicket{} = task, to_status_id, data, opts \\ [])
      when is_binary(to_status_id) and is_map(data) and is_list(opts) do
    with {:ok, client} <- connect(opts) do
      update_task_status(client, task, to_status_id, data, opts)
    end
  end

  @doc """
  Updates a task status and records transition history with an existing SurrealDB client.
  """
  @spec update_task_status(term(), TaskTicket.t(), String.t(), map(), keyword()) ::
          {:ok, TaskTicket.t()} | {:error, term()}
  def update_task_status(client, %TaskTicket{} = task, to_status_id, data, opts)
      when is_binary(to_status_id) and is_map(data) and is_list(opts) do
    query_fun = Keyword.get(opts, :query_fun, &SurrealDB.query/3)

    with {:ok, task_record_id} <- validate_record_id(task.id, "task_ticket"),
         {:ok, workflow_record_id} <- validate_record_id(task.workflow_id, "workflow"),
         {:ok, from_status_record_id} <- validate_record_id(task.status_id, "workflow_status"),
         {:ok, to_status_record_id} <- validate_record_id(to_status_id, "workflow_status"),
         merged_data = Map.merge(task.data, data),
         {:ok, %QueryResult{results: [rows | _]}} <-
           query_fun.(
             client,
             update_task_status_query(
               task_record_id,
               workflow_record_id,
               from_status_record_id,
               to_status_record_id
             ),
             %{data: merged_data}
           ),
         {:ok, task} <- one_task(rows) do
      {:ok, task}
    end
  end

  @doc false
  def list_tasks_query(workflow_record_id) do
    """
    SELECT id, workflow, status, title, data, created_at, updated_at
    FROM task_ticket
    WHERE workflow = #{workflow_record_id}
    ORDER BY created_at ASC, id ASC;
    """
  end

  @doc false
  def list_status_history_query(workflow_record_id) do
    """
    SELECT id, task, workflow, from_status, to_status, data, created_at
    FROM task_status_history
    WHERE workflow = #{workflow_record_id}
    ORDER BY created_at DESC, id DESC;
    """
  end

  @doc false
  def create_task_query(workflow_record_id, status_record_id) do
    """
    CREATE task_ticket CONTENT {
      workflow: #{workflow_record_id},
      status: #{status_record_id},
      title: $title,
      data: $data,
      created_at: time::now(),
      updated_at: time::now()
    };
    """
  end

  @doc false
  def get_task_query(task_record_id) do
    """
    SELECT id, workflow, status, title, data, created_at, updated_at
    FROM #{task_record_id};
    """
  end

  @doc false
  def update_task_status_query(
        task_record_id,
        workflow_record_id,
        from_status_record_id,
        to_status_record_id
      ) do
    """
    UPDATE #{task_record_id}
    SET
      status = #{to_status_record_id},
      data = $data,
      updated_at = time::now();

    CREATE task_status_history CONTENT {
      task: #{task_record_id},
      workflow: #{workflow_record_id},
      from_status: #{from_status_record_id},
      to_status: #{to_status_record_id},
      data: $data,
      created_at: time::now()
    };
    """
  end

  defp connect(opts) do
    opts
    |> Keyword.get(:connect_fun, &SurrealDB.connect/0)
    |> then(& &1.())
  end

  defp to_task(row) when is_map(row) do
    %TaskTicket{
      id: record_id(row["id"]),
      workflow_id: record_id(row["workflow"]),
      status_id: record_id(row["status"]),
      title: row["title"],
      data: row["data"] || %{},
      created_at: to_optional_string(row["created_at"]),
      updated_at: to_optional_string(row["updated_at"])
    }
  end

  defp to_status_history(row) when is_map(row) do
    %TaskStatusHistory{
      id: record_id(row["id"]),
      task_id: record_id(row["task"]),
      workflow_id: record_id(row["workflow"]),
      from_status_id: optional_record_id(row["from_status"]),
      to_status_id: record_id(row["to_status"]),
      data: row["data"] || %{},
      created_at: to_optional_string(row["created_at"])
    }
  end

  defp one_task([row | _]), do: {:ok, to_task(row)}
  defp one_task([]), do: {:error, :task_not_found}
  defp one_task(nil), do: {:error, :task_not_found}

  defp required_attr(attrs, key) do
    value = Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

    if present?(value) do
      {:ok, value}
    else
      {:error, {:missing_required_attr, key}}
    end
  end

  defp validate_record_id(record_id, table) when is_binary(record_id) and is_binary(table) do
    record_id = String.trim(record_id)

    if Regex.match?(~r/\A#{Regex.escape(table)}:[A-Za-z0-9_:-]+\z/, record_id) do
      {:ok, record_id}
    else
      {:error, {:invalid_record_id, record_id, table}}
    end
  end

  defp validate_record_id(record_id, table), do: {:error, {:invalid_record_id, record_id, table}}

  defp record_id(%{"id" => id}), do: record_id(id)
  defp record_id(%{id: id}), do: record_id(id)
  defp record_id(id), do: to_string(id)

  defp optional_record_id(nil), do: nil
  defp optional_record_id(id), do: record_id(id)

  defp to_optional_string(nil), do: nil
  defp to_optional_string(value), do: to_string(value)

  defp present?(value), do: value not in [nil, ""]
end
