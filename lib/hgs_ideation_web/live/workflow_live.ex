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
      |> assign(:history_by_task, %{})
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
    <Layouts.app flash={@flash} full_width>
      <section id="workflow-visualization" class="space-y-6">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase text-base-content/60">
              Workflow
            </p>
            <h1 class="text-2xl font-semibold text-base-content">Kanban FSM</h1>
            <p id="workflow-id" class="mt-1 text-xs font-mono text-base-content/60">
              {@workflow_id}
            </p>
          </div>
          <span class="rounded border border-base-300 px-3 py-1 text-xs font-medium text-base-content/70">
            {length(@statuses)} statuses / {length(@transitions)} transitions / {task_count(
              @tasks_by_status
            )} tasks / {history_count(@history_by_task)} history
          </span>
        </div>

        <div
          :if={@load_error}
          id="workflow-load-error"
          class="rounded border border-error/40 bg-error/10 p-4 text-sm text-error"
        >
          {friendly_error(@load_error, :load)}
        </div>

        <div :if={!@load_error} class="space-y-10">
          <section id="workflow-statuses" class="space-y-3">
            <div
              :if={@task_error}
              id="workflow-task-error"
              class="rounded border border-warning/40 bg-warning/10 p-4 text-sm text-warning"
            >
              {friendly_error(@task_error, :tasks)}
            </div>

            <div class="flex items-start gap-4 overflow-x-auto pb-4">
              <article
                :for={status <- @statuses}
                id={"workflow-status-#{dom_id(status.id)}"}
                class="flex max-h-[calc(100vh-14rem)] w-80 shrink-0 flex-col rounded-xl border border-base-300 bg-base-200/60"
              >
                <header class="flex items-center justify-between gap-2 px-3 py-3">
                  <div class="flex min-w-0 items-center gap-2">
                    <h3 class="truncate text-sm font-semibold">{status.label}</h3>
                    <span class="badge badge-sm badge-ghost font-mono">
                      {length(tasks_for_status(@tasks_by_status, status.id))}
                    </span>
                  </div>
                  <div class="flex shrink-0 gap-1">
                    <span :if={status.initial?} class="badge badge-sm badge-outline badge-success">
                      initial
                    </span>
                    <span :if={status.terminal?} class="badge badge-sm badge-outline badge-info">
                      terminal
                    </span>
                  </div>
                </header>

                <details class="px-3 pb-2 text-xs text-base-content/60">
                  <summary class="cursor-pointer select-none hover:text-base-content/80">
                    Column details
                  </summary>
                  <div class="mt-2 space-y-2">
                    <p class="break-all font-mono">{status.id}</p>
                    <p :if={status.description} class="text-base-content/70">
                      {status.description}
                    </p>
                    <div class="flex flex-wrap gap-1">
                      <span
                        :if={status.required_fields == []}
                        class="rounded bg-base-300/60 px-2 py-0.5"
                      >
                        no required fields
                      </span>
                      <span
                        :for={field <- status.required_fields}
                        class="rounded bg-base-300/60 px-2 py-0.5 font-mono"
                      >
                        {field}
                      </span>
                    </div>
                  </div>
                </details>

                <div
                  id={"workflow-status-#{dom_id(status.id)}-tasks"}
                  class="flex-1 space-y-2 overflow-y-auto px-2 pb-2"
                >
                  <details
                    :if={status.initial?}
                    class="rounded-lg border border-dashed border-base-300 bg-base-100/60"
                  >
                    <summary class="flex cursor-pointer select-none items-center gap-2 px-3 py-2 text-xs font-medium text-base-content/70 hover:text-base-content">
                      <.icon name="hero-plus" class="size-4" /> Add task
                    </summary>

                    <.form
                      for={@create_form}
                      id={"workflow-task-create-#{dom_id(status.id)}"}
                      phx-submit="create_task"
                      class="space-y-2 px-3 pb-3"
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
                        label={field_label(field)}
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
                  </details>

                  <div
                    :if={tasks_for_status(@tasks_by_status, status.id) == []}
                    class="rounded-lg border border-dashed border-base-300 p-3 text-center text-xs text-base-content/50"
                  >
                    No tasks
                  </div>

                  <article
                    :for={task <- tasks_for_status(@tasks_by_status, status.id)}
                    id={"workflow-task-#{dom_id(task.id)}"}
                    class="rounded-lg border border-base-300 bg-base-100 p-3 shadow-sm transition hover:shadow-md"
                  >
                    <h4 class="text-sm font-medium leading-snug">{task.title}</h4>
                    <p class="mt-1 truncate text-[11px] font-mono text-base-content/40">
                      {task.id}
                    </p>

                    <dl :if={task.data != %{}} class="mt-2 space-y-1 text-xs">
                      <div :for={{key, value} <- task_data_pairs(task)} class="flex gap-2">
                        <dt class="shrink-0 font-mono text-base-content/50">{key}</dt>
                        <dd class="min-w-0 break-words text-base-content/80">
                          {task_data_value(value)}
                        </dd>
                      </div>
                    </dl>

                    <details
                      :if={history_for_task(@history_by_task, task.id) != []}
                      id={"workflow-task-#{dom_id(task.id)}-history"}
                      class="mt-2 text-xs"
                    >
                      <summary class="cursor-pointer select-none text-base-content/50 hover:text-base-content/80">
                        History ({length(history_for_task(@history_by_task, task.id))})
                      </summary>

                      <ol class="mt-2 space-y-1.5">
                        <li
                          :for={entry <- history_for_task(@history_by_task, task.id)}
                          id={"workflow-history-#{dom_id(entry.id)}"}
                          class="rounded border border-base-300 bg-base-200/60 p-2"
                        >
                          <div class="flex flex-wrap items-center gap-1">
                            <span class="font-mono text-base-content/60">
                              {short_status(entry.from_status_id)}
                            </span>
                            <.icon name="hero-arrow-right" class="size-3 text-base-content/50" />
                            <span class="font-mono text-base-content/80">
                              {short_status(entry.to_status_id)}
                            </span>
                          </div>

                          <p :if={entry.created_at} class="mt-1 text-base-content/50">
                            {entry.created_at}
                          </p>

                          <dl :if={entry.data != %{}} class="mt-2 grid gap-1">
                            <div :for={{key, value} <- history_data_pairs(entry)}>
                              <dt class="font-mono text-base-content/50">{key}</dt>
                              <dd class="break-words">{task_data_value(value)}</dd>
                            </div>
                          </dl>
                        </li>
                      </ol>
                    </details>

                    <div
                      :if={allowed_moves(@transitions, task) != []}
                      class="mt-3 space-y-1.5 border-t border-base-300/60 pt-2"
                    >
                      <.form
                        :for={transition <- allowed_moves(@transitions, task)}
                        for={@move_form}
                        id={"workflow-task-#{dom_id(task.id)}-move-#{dom_id(transition.to)}"}
                        phx-submit="move_task"
                        class="space-y-2"
                      >
                        <input type="hidden" name="move[task_id]" value={task.id} />
                        <input type="hidden" name="move[to_status_id]" value={transition.to} />

                        <.input
                          :for={field <- missing_required_fields(@statuses, transition, task)}
                          id={"workflow-task-#{dom_id(task.id)}-move-#{dom_id(transition.to)}-#{dom_id(field)}"}
                          name={"move[data][#{field}]"}
                          label={field_label(field)}
                          value=""
                          required
                        />

                        <button
                          id={"workflow-task-#{dom_id(task.id)}-move-#{dom_id(transition.to)}-submit"}
                          type="submit"
                          class="btn btn-xs btn-outline w-full justify-between gap-2"
                        >
                          {move_label(@statuses, transition)}
                          <.icon name="hero-arrow-right" class="size-3" />
                        </button>
                      </.form>
                    </div>
                  </article>
                </div>
              </article>
            </div>
          </section>

          <div class="grid gap-8 2xl:grid-cols-3">
            <section id="workflow-diagram" class="space-y-3">
              <div class="flex items-center gap-2">
                <.icon name="hero-chart-bar-square" class="size-5 text-base-content/60" />
                <h2 class="text-lg font-semibold">FSM Preview</h2>
              </div>

              <div class="rounded border border-base-300 bg-base-100 p-4">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="rounded border border-dashed border-base-300 px-2 py-1 text-xs font-medium text-base-content/60">
                    start
                  </span>

                  <%= for status <- @statuses do %>
                    <.icon name="hero-arrow-right" class="size-4 text-base-content/40" />
                    <div
                      id={"workflow-diagram-status-#{dom_id(status.id)}"}
                      class={[
                        "rounded border px-3 py-2 text-sm shadow-sm",
                        if(status.initial?,
                          do: "border-success/40 bg-success/10",
                          else: "border-base-300 bg-base-200/70"
                        ),
                        status.terminal? && "border-info/40 bg-info/10"
                      ]}
                    >
                      <div class="font-medium">{status.label}</div>
                      <div class="mt-0.5 font-mono text-[11px] text-base-content/50">
                        {short_status(status.id)}
                      </div>
                    </div>
                  <% end %>

                  <.icon name="hero-arrow-right" class="size-4 text-base-content/40" />
                  <span class="rounded border border-dashed border-base-300 px-2 py-1 text-xs font-medium text-base-content/60">
                    end
                  </span>
                </div>

                <div class="mt-4 space-y-2">
                  <div
                    :for={transition <- @transitions}
                    id={"workflow-diagram-transition-#{dom_id(transition.from)}-#{dom_id(transition.to)}"}
                    class="flex flex-wrap items-center gap-2 rounded bg-base-200/70 px-3 py-2 text-xs"
                  >
                    <span class="font-mono text-base-content/70">
                      {short_status(transition.from)}
                    </span>
                    <.icon name="hero-arrow-right" class="size-3 text-base-content/50" />
                    <span class="font-mono text-base-content/80">
                      {short_status(transition.to)}
                    </span>
                    <span class="ml-auto rounded bg-base-100 px-2 py-0.5 text-base-content/60">
                      {transition_label(transition)}
                    </span>
                  </div>
                </div>
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
        {:noreply, put_flash(socket, :error, friendly_error(error, :create))}
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
        {:noreply, put_flash(socket, :error, friendly_error(error, :move))}
    end
  end

  defp load_workflow(socket, workflow_id) do
    case Workflows.load_graph(workflow_id) do
      {:ok, graph} ->
        statuses = Workflows.list_statuses(graph)
        transitions = Workflows.list_transitions(graph)

        socket
        |> assign(:load_error, nil)
        |> assign(:graph, graph)
        |> assign(:statuses, order_statuses_for_board(statuses, transitions))
        |> assign(:transitions, transitions)
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
        |> load_history(workflow_id)

      {:error, error} ->
        assign(socket, :task_error, error)
    end
  end

  defp load_history(socket, workflow_id) do
    case Tasks.list_status_history(workflow_id) do
      {:ok, history} ->
        assign(socket, :history_by_task, Enum.group_by(history, & &1.task_id))

      {:error, error} ->
        socket
        |> assign(:history_by_task, %{})
        |> assign(:task_error, error)
    end
  end

  # Board columns flow left-to-right: initial statuses first, then statuses in
  # breadth-first order along the transition graph, then anything unreachable.
  defp order_statuses_for_board(statuses, transitions) do
    initial_ids = for status <- statuses, status.initial?, do: status.id

    ordered_ids =
      walk_transitions(initial_ids, transitions, MapSet.new(initial_ids), initial_ids)

    remaining_ids =
      statuses
      |> Enum.map(& &1.id)
      |> Enum.reject(&(&1 in ordered_ids))

    position = Map.new(Enum.with_index(ordered_ids ++ remaining_ids))

    Enum.sort_by(statuses, &{Map.fetch!(position, &1.id), &1.label})
  end

  defp walk_transitions([], _transitions, _visited, acc), do: acc

  defp walk_transitions(frontier, transitions, visited, acc) do
    next =
      transitions
      |> Enum.filter(&(&1.from in frontier and not MapSet.member?(visited, &1.to)))
      |> Enum.map(& &1.to)
      |> Enum.uniq()

    walk_transitions(next, transitions, MapSet.union(visited, MapSet.new(next)), acc ++ next)
  end

  defp tasks_for_status(tasks_by_status, status_id) do
    Map.get(tasks_by_status, status_id, [])
  end

  defp history_for_task(history_by_task, task_id) do
    Map.get(history_by_task, task_id, [])
  end

  defp task_data_pairs(task) do
    Enum.sort_by(task.data, fn {key, _value} -> to_string(key) end)
  end

  defp history_data_pairs(entry) do
    Enum.sort_by(entry.data, fn {key, _value} -> to_string(key) end)
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

  defp transition_label(transition), do: transition.label || "allowed"

  defp field_label(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
    |> String.replace_suffix(" id", " ID")
  end

  defp friendly_error({:missing_required_fields, fields}, _context) do
    "Missing required fields: #{Enum.map_join(fields, ", ", &field_label/1)}"
  end

  defp friendly_error({:transition_not_allowed, from, to}, _context) do
    "Cannot move from #{short_status(from)} to #{short_status(to)}"
  end

  defp friendly_error({:unknown_status, status_id}, _context) do
    "Unknown status: #{short_status(status_id)}"
  end

  defp friendly_error({:missing_required_attr, attr}, :create) do
    "Missing required task field: #{field_label(attr)}"
  end

  defp friendly_error(:task_not_found, _context), do: "Task could not be found"
  defp friendly_error(:task_store_unavailable, _context), do: "Task storage is unavailable"

  defp friendly_error(_error, :load), do: "Could not load workflow"
  defp friendly_error(_error, :tasks), do: "Could not load task tickets"
  defp friendly_error(_error, :create), do: "Could not create task"
  defp friendly_error(_error, :move), do: "Could not move task"

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

  defp history_count(history_by_task) do
    history_by_task
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp short_status(nil), do: "start"

  defp short_status(status_id) do
    status_id
    |> to_string()
    |> String.replace_prefix("workflow_status:", "")
  end

  defp dom_id(value) do
    value
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end
end
