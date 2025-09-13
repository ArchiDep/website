defmodule ArchiDep.Events.Types do
  @moduledoc """
  Type definitions for the business events context.
  """

  alias Ecto.UUID

  @type fetch_events_option ::
          {:newer_than, {UUID.t(), DateTime.t()}}
          | {:older_than, {UUID.t(), DateTime.t()}}
          | {:limit, 1..1000}
end
