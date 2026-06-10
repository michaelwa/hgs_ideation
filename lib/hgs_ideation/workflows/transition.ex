defmodule HgsIdeation.Workflows.Transition do
  @moduledoc """
  A directed edge between workflow statuses.
  """

  @enforce_keys [:from, :to]
  defstruct [:from, :to, :label, required_fields: []]

  @type status_id :: HgsIdeation.Workflows.Status.id()

  @type t :: %__MODULE__{
          from: status_id(),
          to: status_id(),
          label: String.t() | nil,
          required_fields: [atom() | String.t()]
        }
end
