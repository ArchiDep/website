defmodule ArchiDep.Events.Context do
  @moduledoc false

  @behaviour ArchiDep.Events.Behaviour

  alias ArchiDep.Events.Behaviour
  alias ArchiDep.Events.UseCases

  @doc false
  @impl Behaviour
  defdelegate fetch_events(auth, opts), to: UseCases.FetchEvents

  @doc false
  @impl Behaviour
  defdelegate fetch_event(auth, id), to: UseCases.FetchEvents
end
