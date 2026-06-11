defmodule HgsIdeationWeb.WorkflowLive do
  use HgsIdeationWeb, :live_view

  alias HgsIdeation.Workflows

  @impl true
  def mount(%{"id" => workflow_id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Workflow #{workflow_id}")
      |> assign(:workflow_id, workflow_id)
      |> assign(:graph, nil)
      |> assign(:statuses, [])
      |> assign(:transitions, [])
      |> assign(:mermaid, nil)
      |> assign(:load_error, nil)
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
              {length(@statuses)} statuses / {length(@transitions)} transitions
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
              <h2 class="text-lg font-semibold">Statuses</h2>
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

  defp load_workflow(socket, workflow_id) do
    case Workflows.load_graph(workflow_id) do
      {:ok, graph} ->
        socket
        |> assign(:graph, graph)
        |> assign(:statuses, Workflows.list_statuses(graph))
        |> assign(:transitions, Workflows.list_transitions(graph))
        |> assign(:mermaid, Workflows.to_mermaid(graph))

      {:error, error} ->
        assign(socket, :load_error, error)
    end
  end

  defp dom_id(value) do
    value
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end
end
