defmodule ArchiDep.Servers.Schemas.ServerRealTimeState do
  import ArchiDep.Servers.ServerConnectionState
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
          set_up_at: DateTime.t() | nil,
          version: non_neg_integer()
        }

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

  @spec deletable?(t()) :: boolean()
  def deletable?(%__MODULE__{connection_state: not_connected_state(), current_job: nil}), do: true
  def deletable?(%__MODULE__{connection_state: connected_state(), current_job: nil}), do: true

  def deletable?(%__MODULE__{connection_state: retry_connecting_state(), current_job: nil}),
    do: true

  def deletable?(%__MODULE__{connection_state: connection_failed_state(), current_job: nil}),
    do: true

  def deletable?(%__MODULE__{connection_state: disconnected_state(), current_job: nil}), do: true
  def deletable?(%__MODULE__{}), do: false
end
