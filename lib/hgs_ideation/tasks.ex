defmodule HgsIdeation.Tasks do
  @moduledoc """
  Public context API for task tickets that move through workflow FSM statuses.
  """

  alias HgsIdeation.Tasks.{SurrealRepo, TaskTicket}
  alias HgsIdeation.Workflows

  @type workflow_id :: String.t()
  @type task_id :: TaskTicket.id()
  @type status_id :: TaskTicket.status_id()

  @doc """
  Lists task tickets for a workflow.
  """
  @spec list_tasks(workflow_id(), keyword()) :: {:ok, [TaskTicket.t()]} | {:error, term()}
  def list_tasks(workflow_id, opts \\ []) when is_binary(workflow_id) and is_list(opts) do
    repository = repo(opts)

    repository.list_tasks(workflow_id, repo_opts(opts))
  end

  @doc """
  Creates a task ticket in a workflow status.
  """
  @spec create_task(workflow_id(), map(), keyword()) :: {:ok, TaskTicket.t()} | {:error, term()}
  def create_task(workflow_id, attrs, opts \\ [])
      when is_binary(workflow_id) and is_map(attrs) and is_list(opts) do
    repository = repo(opts)

    repository.create_task(workflow_id, attrs, repo_opts(opts))
  end

  @doc """
  Moves a task to another status after validating the workflow FSM and compliance fields.
  """
  @spec move_task(task_id(), status_id(), map(), keyword()) ::
          {:ok, TaskTicket.t()} | {:error, term()}
  def move_task(task_id, to_status_id, data \\ %{}, opts \\ [])
      when is_binary(task_id) and is_binary(to_status_id) and is_map(data) and is_list(opts) do
    task_repo = repo(opts)
    task_repo_opts = repo_opts(opts)

    with {:ok, task} <- task_repo.get_task(task_id, task_repo_opts),
         {:ok, graph} <-
           Workflows.load_graph(workflow_slug(task.workflow_id), workflow_opts(opts)),
         merged_data = Map.merge(task.data, data),
         :ok <- Workflows.validate_transition(graph, task.status_id, to_status_id, merged_data) do
      task_repo.update_task_status(task, to_status_id, data, task_repo_opts)
    end
  end

  defp repo(opts) do
    Keyword.get_lazy(opts, :repo, fn ->
      Application.get_env(:hgs_ideation, :task_repo, SurrealRepo)
    end)
  end

  defp repo_opts(opts) do
    Keyword.drop(opts, [:repo, :workflow_loader])
  end

  defp workflow_opts(opts) do
    opts
    |> Keyword.take([:workflow_loader])
    |> Keyword.new(fn {:workflow_loader, loader} -> {:loader, loader} end)
  end

  defp workflow_slug("workflow:" <> slug), do: slug
  defp workflow_slug(workflow_id), do: workflow_id
end
