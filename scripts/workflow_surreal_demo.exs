defmodule WorkflowSurrealDemo do
  @moduledoc false

  alias HgsIdeation.Workflows.{Graph, SurrealRepo}

  @workflow_slug "support"
  @workflow_record "workflow:support"
  @migrations_path Path.expand("../priv/surrealdb_migrations/hgs_ideation", __DIR__)

  def run do
    with {:ok, client} <- SurrealDB.connect(),
         {:ok, migration_result} <- apply_migrations(client),
         {:ok, _seed_result} <- seed_demo_workflow(client),
         {:ok, graph} <- SurrealRepo.load_graph(client, @workflow_slug, []),
         :ok <-
           Graph.validate_transition(
             graph,
             "workflow_status:support_review",
             "workflow_status:support_done",
             %{"approved_by" => "user:demo", "resolution" => "Demo complete"}
           ) do
      IO.puts("Workflow graph demo loaded from SurrealDB.")
      IO.inspect(migration_result.statuses, label: "migration statuses")
      IO.puts("\nMermaid stateDiagram-v2:\n")
      IO.puts(Graph.to_mermaid(graph))
    else
      {:error, error} ->
        IO.puts("Workflow graph demo failed.")
        IO.inspect(error, label: "error")
        System.halt(1)
    end
  end

  defp apply_migrations(client) do
    @migrations_path
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".surql"))
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn filename, {:ok, acc} ->
      path = Path.join(@migrations_path, filename)

      case SurrealDB.query(client, File.read!(path)) do
        {:ok, result} -> {:cont, {:ok, [result | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, [result | _]} -> {:ok, result}
      {:ok, []} -> {:error, {:no_migrations_found, @migrations_path}}
      error -> error
    end
  end

  defp seed_demo_workflow(client) do
    SurrealDB.query(client, seed_query())
  end

  defp seed_query do
    """
    DELETE can_transition_to WHERE workflow = #{@workflow_record};
    DELETE workflow_status WHERE workflow = #{@workflow_record};
    DELETE #{@workflow_record};

    CREATE #{@workflow_record} CONTENT {
      slug: '#{@workflow_slug}',
      name: 'Support Workflow',
      description: 'Demo FSM workflow for kanban task status transitions',
      created_at: time::now(),
      updated_at: time::now()
    };

    CREATE workflow_status:support_todo CONTENT {
      workflow: #{@workflow_record},
      label: 'Todo',
      description: 'New work waiting to be started',
      required_fields: [],
      initial: true,
      terminal: false,
      lane_order: 10,
      created_at: time::now(),
      updated_at: time::now()
    };

    CREATE workflow_status:support_in_progress CONTENT {
      workflow: #{@workflow_record},
      label: 'In Progress',
      description: 'Work that has an owner',
      required_fields: ['assignee_id'],
      initial: false,
      terminal: false,
      lane_order: 20,
      created_at: time::now(),
      updated_at: time::now()
    };

    CREATE workflow_status:support_review CONTENT {
      workflow: #{@workflow_record},
      label: 'Review',
      description: 'Work waiting for approval',
      required_fields: ['reviewer_id'],
      initial: false,
      terminal: false,
      lane_order: 30,
      created_at: time::now(),
      updated_at: time::now()
    };

    CREATE workflow_status:support_done CONTENT {
      workflow: #{@workflow_record},
      label: 'Done',
      description: 'Completed work',
      required_fields: ['resolution'],
      initial: false,
      terminal: true,
      lane_order: 40,
      created_at: time::now(),
      updated_at: time::now()
    };

    RELATE workflow_status:support_todo->can_transition_to->workflow_status:support_in_progress
      CONTENT {
        workflow: #{@workflow_record},
        label: 'start work',
        required_fields: [],
        created_at: time::now(),
        updated_at: time::now()
      };

    RELATE workflow_status:support_in_progress->can_transition_to->workflow_status:support_review
      CONTENT {
        workflow: #{@workflow_record},
        label: 'request review',
        required_fields: ['review_notes'],
        created_at: time::now(),
        updated_at: time::now()
      };

    RELATE workflow_status:support_review->can_transition_to->workflow_status:support_in_progress
      CONTENT {
        workflow: #{@workflow_record},
        label: 'request changes',
        required_fields: [],
        created_at: time::now(),
        updated_at: time::now()
      };

    RELATE workflow_status:support_review->can_transition_to->workflow_status:support_done
      CONTENT {
        workflow: #{@workflow_record},
        label: 'approve',
        required_fields: ['approved_by'],
        created_at: time::now(),
        updated_at: time::now()
      };
    """
  end

end

WorkflowSurrealDemo.run()
