defmodule ArchiDep.Clock.SystemClock do
  @moduledoc """
  Default `ArchiDep.Clock` implementation returning the current system time in
  UTC.
  """

  @behaviour ArchiDep.Clock.Behaviour

  @impl ArchiDep.Clock.Behaviour
  def now, do: DateTime.utc_now()
end
