defmodule ArchiDep.Servers.Schemas.ServerRealTimeState do
  alias ArchiDep.Servers.ServerConnectionState
  alias ArchiDep.Servers.Types

  @type t :: %__MODULE__{
          connection_state: ServerConnectionState.connection_state(),
          name: String.t() | nil,
          conn_params: {:inet.ip_address(), 1..65_535, String.t()},
          username: String.t(),
          app_username: String.t(),
          current_job: Types.server_job(),
          problems: list(Types.server_problem()),
          version: non_neg_integer()
        }

  @enforce_keys [:connection_state, :name, :conn_params, :username, :app_username]
  defstruct [
    :connection_state,
    :name,
    :conn_params,
    :username,
    :app_username,
    current_job: nil,
    problems: [],
    version: 0
  ]
end
