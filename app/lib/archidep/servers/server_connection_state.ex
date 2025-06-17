defmodule ArchiDep.Servers.ServerConnectionState do
  require Record

  Record.defrecord(:connecting_state,
    connection_ref: nil,
    connection_pid: nil,
    retrying: false
  )

  Record.defrecord(:connected_state, time: nil, connection_ref: nil, connection_pid: nil)

  Record.defrecord(:reconnecting_state,
    connection_ref: nil,
    connection_pid: nil,
    retrying: false
  )

  Record.defrecord(:connection_failed_state, connection_pid: nil, reason: nil)

  Record.defrecord(:disconnected_state, time: nil)

  @type connecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid(),
            retrying: false | {pos_integer(), DateTime.t(), pos_integer(), term}
          )

  @type connected_state ::
          record(:connected_state, connection_ref: reference(), connection_pid: pid())

  @type reconnecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid(),
            retrying: false | {pos_integer(), DateTime.t(), pos_integer(), term}
          )

  @type connection_failed_state ::
          record(:connection_failed_state, connection_pid: pid(), reason: term())

  @type disconnected_state :: record(:disconnected_state, time: DateTime.t())

  @type connection_state ::
          :not_connected
          | connecting_state()
          | connected_state()
          | reconnecting_state()
          | disconnected_state()
          | connection_failed_state()
end
