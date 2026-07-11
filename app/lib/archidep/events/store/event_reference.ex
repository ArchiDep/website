defmodule ArchiDep.Events.Store.EventReference do
  @moduledoc """
  A reference to a stored event that can be passed around to form event chains
  through the causation and correlation IDs, without having to hold the entire
  event data.
  """

  alias Ecto.UUID

  @enforce_keys [:id, :causation_id, :correlation_id, :version, :occurred_at]
  defstruct [:id, :causation_id, :correlation_id, :version, :occurred_at]

  @type t :: %__MODULE__{
          id: UUID.t(),
          causation_id: UUID.t(),
          correlation_id: UUID.t(),
          version: pos_integer(),
          occurred_at: DateTime.t()
        }
end
