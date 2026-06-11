defmodule HgsIdeation.Tasks.TaskStatusHistory do
  @moduledoc """
  Audit entry for a task status transition.
  """

  @enforce_keys [:id, :task_id, :workflow_id, :to_status_id]
  defstruct [
    :id,
    :task_id,
    :workflow_id,
    :from_status_id,
    :to_status_id,
    data: %{},
    created_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          task_id: String.t(),
          workflow_id: String.t(),
          from_status_id: String.t() | nil,
          to_status_id: String.t(),
          data: map(),
          created_at: String.t() | nil
        }
end
