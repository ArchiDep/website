defmodule ArchiDep.Servers.Schemas.ServerRealTimeState do
  alias ArchiDep.Servers.ServerConnectionState
  alias Ecto.UUID

  @type t :: %__MODULE__{
          state: :initial_setup | :tracked | :corrupted,
          connection_state: ServerConnectionState.connection_state(),
          name: String.t() | nil,
          conn_params: {:inet.ip_address(), 1..65_535, String.t()},
          username: String.t(),
          app_username: String.t(),
          current_job:
            :connecting
            | :reconnecting
            | :checking_access
            | :setting_up_app_user
            | :gathering_facts
            | {:running_playbook, String.t(), UUID.t()}
            | nil,
          version: non_neg_integer()
        }

  @enforce_keys [:state, :connection_state, :name, :conn_params, :username, :app_username]
  defstruct [
    :state,
    :connection_state,
    :name,
    :conn_params,
    :username,
    :app_username,
    current_job: nil,
    version: 0
  ]
end
