defmodule ArchiDep.PubSub.Scope do
  @moduledoc """
  Per-process suffix applied to global (non-keyed) PubSub topics.

  Some topics are shared by every subscriber rather than keyed by a resource id
  — currently `"classes"` (the admin classes list) and `"servers:new"` (newly
  created servers). Unlike the SQL sandbox, `Phoenix.PubSub` is process-global,
  so a broadcast on such a topic reaches every subscribed process, including
  concurrent `async: true` tests. Resolving these topic names through
  `global_topic/1` lets the test environment scope them per test, so each test
  observes only its own broadcasts and can assert whole lists by equality.

  In production the suffix is empty (`ArchiDep.PubSub.Scope.GlobalScope`) and
  the topics keep their shared names; in the test environment it is configured
  to a mock that each test stubs with a unique suffix. Keyed topics (e.g.
  `"classes:\#{id}"`) are already isolated by their resource id and are not
  scoped. See the testing guide in `docs/testing.md`.
  """

  @behaviour ArchiDep.PubSub.Scope.Behaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  @doc """
  Returns the given global topic name with the current scope suffix appended.
  """
  @spec global_topic(String.t()) :: String.t()
  def global_topic(name), do: name <> suffix()

  defdelegate suffix, to: @implementation
end
