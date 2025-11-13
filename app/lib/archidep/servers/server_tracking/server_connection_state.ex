defmodule ArchiDep.Servers.ServerTracking.ServerConnectionState do
  @moduledoc """
  The state of a server connection, which can be in various states such as not
  connected yet, connecting, connected, retrying to connect, or disconnected.
  """

  alias ArchiDep.Events.Store.EventReference
  require Record

  Record.defrecord(:not_connected_state, connection_pid: nil)

  Record.defrecord(:connection_pending_state,
    connection_pid: nil,
    causation_event: nil
  )

  Record.defrecord(:connecting_state,
    connection_ref: nil,
    connection_pid: nil,
    time: nil,
    retrying: nil,
    causation_event: nil
  )

  Record.defrecord(:retry_connecting_state,
    connection_pid: nil,
    retrying: nil
  )

  Record.defrecord(:connected_state,
    connection_ref: nil,
    connection_pid: nil,
    time: nil,
    connection_event: nil,
    retry_event: nil
  )

  Record.defrecord(:reconnecting_state,
    connection_ref: nil,
    connection_pid: nil,
    time: nil,
    causation_event: nil
  )

  Record.defrecord(:connection_failed_state, connection_pid: nil, reason: nil)

  Record.defrecord(:disconnected_state, time: nil)

  @type retry :: %{
          retry: pos_integer(),
          backoff: non_neg_integer(),
          time: DateTime.t(),
          in_seconds: pos_integer(),
          reason: term()
        }

  @type not_connected_state :: record(:not_connected_state, connection_pid: pid() | nil)

  @type connection_pending_state ::
          record(:connection_pending_state,
            connection_pid: pid(),
            causation_event: EventReference.t() | nil
          )

  @type connecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid(),
            time: DateTime.t(),
            retrying: retry() | false,
            causation_event: EventReference.t() | nil
          )

  @type retry_connecting_state ::
          record(:retry_connecting_state,
            connection_pid: pid(),
            retrying: retry()
          )

  @type connected_state ::
          record(:connected_state,
            connection_ref: reference(),
            connection_pid: pid(),
            time: DateTime.t(),
            connection_event: EventReference.t(),
            retry_event: EventReference.t() | nil
          )

  @type reconnecting_state ::
          record(:reconnecting_state,
            connection_ref: reference(),
            connection_pid: pid(),
            time: DateTime.t(),
            causation_event: EventReference.t()
          )

  @type connection_failed_state ::
          record(:connection_failed_state, connection_pid: pid(), reason: term())

  @type disconnected_state :: record(:disconnected_state, time: DateTime.t())

  @type connection_state ::
          not_connected_state()
          | connection_pending_state()
          | connecting_state()
          | retry_connecting_state()
          | connected_state()
          | reconnecting_state()
          | disconnected_state()
          | connection_failed_state()

  @spec connecting?(connection_state()) :: boolean()
  def connecting?(state), do: Record.is_record(state, :connecting_state)

  @spec retry_connecting?(connection_state()) :: boolean()
  def retry_connecting?(state), do: Record.is_record(state, :retry_connecting_state)

  @spec connected?(connection_state()) :: boolean()
  def connected?(state), do: Record.is_record(state, :connected_state)

  @spec not_connected?(connection_state()) :: boolean()
  def not_connected?(state), do: Record.is_record(state, :not_connected_state)

  @spec connection_failed?(connection_state()) :: boolean()
  def connection_failed?(state), do: Record.is_record(state, :connection_failed_state)

  @spec connection_pid(connection_state()) :: pid() | nil
  def connection_pid(not_connected_state(connection_pid: pid)), do: pid
  def connection_pid(connection_pending_state(connection_pid: pid)), do: pid
  def connection_pid(connecting_state(connection_pid: pid)), do: pid
  def connection_pid(retry_connecting_state(connection_pid: pid)), do: pid
  def connection_pid(connected_state(connection_pid: pid)), do: pid
  def connection_pid(reconnecting_state(connection_pid: pid)), do: pid
  def connection_pid(connection_failed_state(connection_pid: pid)), do: pid
  def connection_pid(disconnected_state()), do: nil
end
