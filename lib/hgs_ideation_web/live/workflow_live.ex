defmodule HgsIdeationWeb.WorkflowLive do
  use HgsIdeationWeb, :live_view

  alias HgsIdeation.{Tasks, Workflows}

  @impl true
  def mount(%{"id" => workflow_id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Workflow #{workflow_id}")
      |> assign(:workflow_id, workflow_id)
      |> assign(:graph, nil)
      |> assign(:statuses, [])
      |> assign(:transitions, [])
      |> assign(:tasks_by_status, %{})
      |> assign(:move_form, to_form(%{}, as: :move))
      |> assign(:create_form, to_form(%{}, as: :task))
      |> assign(:mermaid, nil)
      |> assign(:load_error, nil)
      |> assign(:task_error, nil)
      |> load_workflow(workflow_id)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="workflow-visualization" class="space-y-8">
        <div class="space-y-3">
          <p class="text-sm font-semibold uppercase text-base-content/60">
            Workflow
          </p>
          <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h1 class="text-3xl font-semibold text-base-content">Kanban FSM</h1>
              <p id="workflow-id" class="mt-2 text-sm font-mono text-base-content/70">
                {@workflow_id}
              </p>
            </div>
            <span class="rounded border border-base-300 px-3 py-1 text-xs font-medium text-base-content/70">
              {length(@statuses)} statuses / {length(@transitions)} transitions / {task_count(
                @tasks_by_status
              )} tasks
            </span>
          </div>
        </div>

        <div
          :if={@load_error}
          id="workflow-load-error"
          class="rounded border border-error/40 bg-error/10 p-4 text-sm text-error"
        >
          Could not load workflow: {inspect(@load_error)}
        </div>

        <div :if={!@load_error} class="space-y-8">
          <section id="workflow-statuses" class="space-y-3">
            <div class="flex items-center gap-2">
              <.icon name="hero-rectangle-stack" class="size-5 text-base-content/60" />
              <h2 class="text-lg font-semibold">Board</h2>
            </div>

            <div
              :if={@task_error}
              id="workflow-task-error"
              class="rounded border border-warning/40 bg-warning/10 p-4 text-sm text-warning"
            >
              Could not load task tickets: {inspect(@task_error)}
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <article
                :for={status <- @statuses}
                id={"workflow-status-#{dom_id(status.id)}"}
                class="rounded border border-base-300 bg-base-100 p-4 shadow-sm transition hover:border-base-content/30"
              >
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <h3 class="font-semibold">{status.label}</h3>
                    <p class="mt-1 text-xs font-mono text-base-content/50">{status.id}</p>
                  </div>
                  <div class="flex gap-1">
                    <span
                      :if={status.initial?}
                      class="rounded border border-success/40 px-2 py-1 text-xs text-success"
                    >
                      initial
                    </span>
                    <span
                      :if={status.terminal?}
                      class="rounded border border-info/40 px-2 py-1 text-xs text-info"
                    >
                      terminal
                    </span>
                  </div>
                </div>

                <div class="mt-5 space-y-2">
                  <div class="flex items-center justify-between gap-3">
                    <p class="text-xs font-semibold uppercase text-base-content/50">Tasks</p>
                    <span class="rounded bg-base-200 px-2 py-1 text-xs text-base-content/60">
                      {length(tasks_for_status(@tasks_by_status, status.id))}
                    </span>
                  </div>

                  <div
                    id={"workflow-status-#{dom_id(status.id)}-tasks"}
                    class="space-y-2"
                  >
                    <.form
                      :if={status.initial?}
                      for={@create_form}
                      id={"workflow-task-create-#{dom_id(status.id)}"}
                      phx-submit="create_task"
                      class="space-y-2 rounded border border-base-300 bg-base-100 p-2"
                    >
                      <input type="hidden" name="task[status_id]" value={status.id} />

                      <.input
                        id={"workflow-task-create-#{dom_id(status.id)}-title"}
                        name="task[title]"
                        label="Title"
                        value=""
                        required
                      />

                      <.input
                        :for={field <- status.required_fields}
                        id={"workflow-task-create-#{dom_id(status.id)}-#{dom_id(field)}"}
                        name={"task[data][#{field}]"}
                        label={field}
                        value=""
                        required
                      />

                      <button
                        id={"workflow-task-create-#{dom_id(status.id)}-submit"}
                        type="submit"
                        class="btn btn-sm btn-primary w-full gap-2"
                      >
                        <.icon name="hero-plus" class="size-4" /> Create task
                      </button>
                    </.form>

                    <div
                      :if={tasks_for_status(@tasks_by_status, status.id) == []}
                      class="rounded border border-dashed border-base-300 p-3 text-xs text-base-content/50"
                    >
                      No tasks
                    </div>

                    <article
                      :for={task <- tasks_for_status(@tasks_by_status, status.id)}
                      id={"workflow-task-#{dom_id(task.id)}"}
                      class="rounded border border-base-300 bg-base-200 p-3"
                    >
                      <h4 class="text-sm font-semibold">{task.title}</h4>
                      <p class="mt-1 text-xs font-mono text-base-content/50">{task.id}</p>

                      <dl :if={task.data != %{}} class="mt-3 grid gap-2 text-xs">
                        <div :for={{key, value} <- task_data_pairs(task)}>
                          <dt class="font-mono text-base-content/50">{key}</dt>
                          <dd class="mt-0.5 break-words">{task_data_value(value)}</dd>
                        </div>
                      </dl>

                      <div :if={allowed_moves(@transitions, task) != []} class="mt-4 space-y-2">
                        <p class="text-xs font-semibold uppercase text-base-content/50">Move</p>

                        <.form
                          :for={transition <- allowed_moves(@transitions, task)}
                          for={@move_form}
                          id={"workflow-task-#{dom_id(task.id)}-move-#{dom_id(transition.to)}"}
                          phx-submit="move_task"
                          class="space-y-2 rounded border border-base-300 bg-base-100 p-2"
                        >
                          <input type="hidden" name="move[task_id]" value={task.id} />
                          <input type="hidden" name="move[to_status_id]" value={transition.to} />

                          <.input
                            :for={field <- missing_required_fields(@statuses, transition, task)}
                            id={"workflow-task-#{dom_id(task.id)}-move-#{dom_id(transition.to)}-#{dom_id(field)}"}
                            name={"move[data][#{field}]"}
                            label={field}
                            value=""
                            required
                          />

                          <button
                            id={"workflow-task-#{dom_id(task.id)}-move-#{dom_id(transition.to)}-submit"}
                            type="submit"
                            class="btn btn-sm btn-primary w-full gap-2"
                          >
                            <.icon name="hero-arrow-right" class="size-4" />
                            {move_label(@statuses, transition)}
                          </button>
                        </.form>
                      </div>
                    </article>
                  </div>
                </div>

                <p :if={status.description} class="mt-3 text-sm text-base-content/70">
                  {status.description}
                </p>

                <div class="mt-4 space-y-2">
                  <p class="text-xs font-semibold uppercase text-base-content/50">
                    Required fields
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <span
                      :if={status.required_fields == []}
                      class="rounded bg-base-200 px-2 py-1 text-xs text-base-content/60"
                    >
                      none
                    </span>
                    <span
                      :for={field <- status.required_fields}
                      class="rounded bg-base-200 px-2 py-1 text-xs font-mono"
                    >
                      {field}
                    </span>
                  </div>
                </div>
              </article>
            </div>
          </section>

          <section id="workflow-transitions" class="space-y-3">
            <div class="flex items-center gap-2">
              <.icon name="hero-arrows-right-left" class="size-5 text-base-content/60" />
              <h2 class="text-lg font-semibold">Allowed Transitions</h2>
            </div>

            <div class="overflow-hidden rounded border border-base-300">
              <table class="w-full text-sm">
                <thead class="bg-base-200 text-left text-xs uppercase text-base-content/60">
                  <tr>
                    <th class="px-3 py-2">From</th>
                    <th class="px-3 py-2">To</th>
                    <th class="px-3 py-2">Rule</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-base-300">
                  <tr
                    :for={transition <- @transitions}
                    id={"workflow-transition-#{dom_id(transition.from)}-#{dom_id(transition.to)}"}
                  >
                    <td class="px-3 py-2 font-mono text-xs">{transition.from}</td>
                    <td class="px-3 py-2 font-mono text-xs">{transition.to}</td>
                    <td class="px-3 py-2">{transition.label || "allowed"}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section id="workflow-mermaid" class="space-y-3">
            <div class="flex items-center gap-2">
              <.icon name="hero-code-bracket-square" class="size-5 text-base-content/60" />
              <h2 class="text-lg font-semibold">Mermaid stateDiagram-v2</h2>
            </div>
            <pre class="overflow-x-auto rounded border border-base-300 bg-base-200 p-4 text-xs leading-6"><code>{@mermaid}</code></pre>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event(
        "create_task",
        %{"task" => %{"status_id" => status_id, "title" => title} = params},
        socket
      ) do
    data =
      params
      |> Map.get("data", %{})
      |> Map.reject(fn {_key, value} -> value in [nil, ""] end)

    case Tasks.create_task(socket.assigns.workflow_id, %{
           status_id: status_id,
           title: title,
           data: data
         }) do
      {:ok, _task} ->
        socket =
          socket
          |> put_flash(:info, "Task created")
          |> load_workflow(socket.assigns.workflow_id)

        {:noreply, socket}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Create rejected: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event(
        "move_task",
        %{"move" => %{"task_id" => task_id, "to_status_id" => to_status_id} = params},
        socket
      ) do
    data =
      params
      |> Map.get("data", %{})
      |> Map.reject(fn {_key, value} -> value in [nil, ""] end)

    case Tasks.move_task(task_id, to_status_id, data) do
      {:ok, _task} ->
        socket =
          socket
          |> put_flash(:info, "Task moved")
          |> load_workflow(socket.assigns.workflow_id)

        {:noreply, socket}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Move rejected: #{inspect(error)}")}
    end
  end

  defp load_workflow(socket, workflow_id) do
    case Workflows.load_graph(workflow_id) do
      {:ok, graph} ->
        socket
        |> assign(:load_error, nil)
        |> assign(:graph, graph)
        |> assign(:statuses, Workflows.list_statuses(graph))
        |> assign(:transitions, Workflows.list_transitions(graph))
        |> assign(:mermaid, Workflows.to_mermaid(graph))
        |> load_tasks(workflow_id)

      {:error, error} ->
        assign(socket, :load_error, error)
    end
  end

  defp load_tasks(socket, workflow_id) do
    case Tasks.list_tasks(workflow_id) do
      {:ok, tasks} ->
        socket
        |> assign(:task_error, nil)
        |> assign(:tasks_by_status, Enum.group_by(tasks, & &1.status_id))

      {:error, error} ->
        assign(socket, :task_error, error)
    end
  end

  defp tasks_for_status(tasks_by_status, status_id) do
    Map.get(tasks_by_status, status_id, [])
  end

  defp task_data_pairs(task) do
    Enum.sort_by(task.data, fn {key, _value} -> to_string(key) end)
  end

  defp task_data_value(value) when is_binary(value), do: value
  defp task_data_value(value), do: inspect(value)

  defp allowed_moves(transitions, task) do
    Enum.filter(transitions, &(&1.from == task.status_id))
  end

  defp missing_required_fields(statuses, transition, task) do
    target_status = Enum.find(statuses, &(&1.id == transition.to))
    status_fields = if target_status, do: target_status.required_fields, else: []

    (status_fields ++ transition.required_fields)
    |> Enum.uniq()
    |> Enum.reject(fn field ->
      task.data
      |> get_task_data(field)
      |> present?()
    end)
  end

  defp move_label(statuses, transition) do
    case Enum.find(statuses, &(&1.id == transition.to)) do
      nil -> "Move"
      status -> "Move to #{status.label}"
    end
  end

  defp get_task_data(data, field) when is_atom(field) do
    Map.get(data, field) || Map.get(data, Atom.to_string(field))
  end

  defp get_task_data(data, field) when is_binary(field) do
    Map.get(data, field)
  end

  defp present?(value), do: value not in [nil, ""]

  defp task_count(tasks_by_status) do
    tasks_by_status
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp dom_id(value) do
    value
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end
end
