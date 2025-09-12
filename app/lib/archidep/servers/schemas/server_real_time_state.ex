defmodule ArchiDep.Servers.Schemas.ServerRealTimeState do
  @moduledoc """
  The real-time state of a server, including its connection status and any
  current job or problems. Used to communicate the server's current state to the
  UI.
  """

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.Types

  @enforce_keys [:connection_state, :name, :conn_params, :username, :app_username]
  defstruct [
    :connection_state,
    :name,
    :conn_params,
    :username,
    :app_username,
    :set_up_at,
    current_job: nil,
    problems: [],
    version: 0
  ]

  @type t :: %__MODULE__{
          connection_state: ServerConnectionState.connection_state(),
          name: String.t() | nil,
          conn_params: {:inet.ip_address(), 1..65_535, String.t()},
          username: String.t(),
          app_username: String.t(),
          current_job: Types.server_job(),
          problems: list(Types.server_problem()),
          set_up_at: DateTime.t() | nil,
          version: non_neg_integer()
        }

  @spec busy?(t() | nil) :: boolean()
  def busy?(nil), do: false
  def busy?(%__MODULE__{connection_state: not_connected_state(), current_job: nil}), do: false
  def busy?(%__MODULE__{connection_state: connected_state(), current_job: nil}), do: false

  def busy?(%__MODULE__{connection_state: retry_connecting_state(), current_job: nil}),
    do: false

  def busy?(%__MODULE__{connection_state: connection_failed_state(), current_job: nil}),
    do: false

  def busy?(%__MODULE__{connection_state: disconnected_state(), current_job: nil}), do: false
  def busy?(%__MODULE__{}), do: true

  @spec problem?(t() | nil, list(atom())) :: boolean()
  def problem?(nil, _types), do: false

  def problem?(%__MODULE__{problems: problems}, types) when is_list(types),
    do: Enum.any?(problems, &(elem(&1, 0) in types))
end
