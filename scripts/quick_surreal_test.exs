defmodule QuickSurrealTest do
  @moduledoc false

  @table "quick_test"

  def run do
    IO.puts("Connecting to SurrealDB with :hgs_surrealdb_sdk application config...")

    with {:ok, client} <- SurrealDB.connect(),
         :ok <- query(client, "RETURN 'connected'", "connectivity check"),
         {:ok, id} <- create_record(client),
         :ok <- read_record(client, id),
         :ok <- delete_record(client, id) do
      IO.puts("\nSurrealDB quick test passed.")
    else
      {:error, error} ->
        IO.puts("\nSurrealDB quick test failed.")
        print_config_hint(error)
        IO.inspect(error, label: "error")
        System.halt(1)
    end
  end

  defp create_record(client) do
    id = "#{@table}:#{System.unique_integer([:positive])}"

    case query(
           client,
           "CREATE #{id} CONTENT $data",
           %{
             data: %{
               name: "IEx quick test",
               inserted_at: DateTime.utc_now() |> DateTime.to_iso8601()
             }
           },
           "create #{id}"
         ) do
      :ok -> {:ok, id}
      {:error, error} -> {:error, error}
    end
  end

  defp read_record(client, id) do
    query(client, "SELECT * FROM #{id}", "read #{id}")
  end

  defp delete_record(client, id) do
    query(client, "DELETE #{id}", "delete #{id}")
  end

  defp query(client, sql, label) do
    query(client, sql, %{}, label)
  end

  defp query(client, sql, vars, label) do
    IO.puts("\n-- #{label}")
    IO.puts(sql)

    case SurrealDB.query(client, sql, vars) do
      {:ok, result} ->
        IO.inspect(result.results, label: "results")
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  defp print_config_hint(%SurrealDB.Error{message: "The namespace " <> _}) do
    connection = Application.get_env(:hgs_surrealdb_sdk, :connection, [])

    IO.puts("""

    The connection worked, but the configured namespace/database was not usable.

    Current config:
      endpoint:  #{Keyword.get(connection, :endpoint)}
      namespace: #{Keyword.get(connection, :namespace)}
      database:  #{Keyword.get(connection, :database)}

    Override these for a one-off run if your local SurrealDB uses a different scope:
      SURREALDB_NAMESPACE=test SURREALDB_DATABASE=test mix run scripts/quick_surreal_test.exs
    """)
  end

  defp print_config_hint(_error), do: :ok
end

QuickSurrealTest.run()
