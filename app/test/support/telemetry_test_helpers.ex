defmodule ArchiDep.Support.TelemetryTestHelpers do
  @moduledoc """
  Helpers for working with telemetry events in tests.
  """

  import ExUnit.Callbacks
  import ExUnit.Assertions

  @spec attach_telemetry_handler!(%{test: atom(), test_pid: pid()}, list(atom())) :: :ok
  def attach_telemetry_handler!(%{test: test, test_pid: test_pid}, event) when is_list(event) do
    handler_id = "#{test}-#{Enum.map_join(event, "-", &to_string/1)}-telemetry"

    :ok =
      :telemetry.attach(
        handler_id,
        event,
        fn ^event, measurements, metadata, config ->
          # Telemetry handlers are global, so this handler fires for every
          # emission of the event across the whole VM — including events emitted
          # by other tests running concurrently under `async: true`. These use
          # cases emit synchronously in the test process, so only forward events
          # emitted by this test's own process to avoid cross-talk between tests
          # that share an event name (see `docs/testing.md`).
          if self() == test_pid do
            send(
              test_pid,
              {:telemetry_event, event,
               %{measurements: measurements, metadata: metadata, config: config}}
            )
          end
        end,
        nil
      )

    on_exit(fn ->
      :ok = :telemetry.detach(handler_id)
    end)
  end

  @spec assert_telemetry_event!(list(atom())) :: %{
          measurements: map(),
          metadata: map(),
          config: term()
        }
  def assert_telemetry_event!(event) when is_list(event) do
    assert_receive {:telemetry_event, ^event, data}
    data
  end
end
