defmodule HgsIdeation.Tasks.TaskTicket do
  @moduledoc """
  A task ticket assigned to a workflow status.
  """

  @enforce_keys [:id, :workflow_id, :status_id, :title]
  defstruct [:id, :workflow_id, :status_id, :title, data: %{}, created_at: nil, updated_at: nil]

  @type id :: String.t()
  @type status_id :: String.t()
  @type workflow_id :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          workflow_id: workflow_id(),
          status_id: status_id(),
          title: String.t(),
          data: map(),
          created_at: String.t() | nil,
          updated_at: String.t() | nil
        }
end
