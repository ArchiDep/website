defmodule ArchiDep.Servers.ServerConnectionState do
  require Record

  Record.defrecord(:connecting_state,
    connection_ref: nil,
    connection_pid: nil,
    retrying: nil
  )

  Record.defrecord(:retry_connecting_state,
    connection_pid: nil,
    retrying: nil
  )

  Record.defrecord(:connected_state, time: nil, connection_ref: nil, connection_pid: nil)

  Record.defrecord(:reconnecting_state,
    connection_ref: nil,
    connection_pid: nil
  )

  Record.defrecord(:connection_failed_state, connection_pid: nil, reason: nil)

  Record.defrecord(:disconnected_state, time: nil)

  @type retry :: %{
          retry: pos_integer(),
          backoff: pos_integer(),
          time: DateTime.t(),
          in_seconds: pos_integer(),
          reason: term()
        }

  @type connecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid(),
            retrying: retry() | false
          )

  @type retry_connecting_state ::
          record(:retry_connecting_state,
            connection_pid: pid(),
            retrying: retry()
          )

  @type connected_state ::
          record(:connected_state, connection_ref: reference(), connection_pid: pid())

  @type reconnecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid()
          )

  @type connection_failed_state ::
          record(:connection_failed_state, connection_pid: pid(), reason: term())

  @type disconnected_state :: record(:disconnected_state, time: DateTime.t())

  @type connection_state ::
          :not_connected
          | connecting_state()
          | retry_connecting_state()
          | connected_state()
          | reconnecting_state()
          | disconnected_state()
          | connection_failed_state()
end
