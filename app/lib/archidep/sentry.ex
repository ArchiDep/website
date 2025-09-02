defmodule ArchiDep.Sentry do
  @moduledoc """
  Sentry event filtering (see
  https://docs.sentry.io/platforms/elixir/configuration/filtering/).
  """

  @spec before_send(map()) :: map() | nil
  def before_send(%{environment: "test"}), do: nil
  def before_send(event), do: event
end
