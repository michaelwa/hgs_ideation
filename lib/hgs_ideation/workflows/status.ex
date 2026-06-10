defmodule HgsIdeation.Workflows.Status do
  @moduledoc """
  A workflow state that can be rendered as a kanban swim lane.
  """

  @enforce_keys [:id, :label]
  defstruct [:id, :label, :description, required_fields: [], initial?: false, terminal?: false]

  @type id :: atom() | String.t()

  @type t :: %__MODULE__{
          id: id(),
          label: String.t(),
          description: String.t() | nil,
          required_fields: [atom() | String.t()],
          initial?: boolean(),
          terminal?: boolean()
        }
end
