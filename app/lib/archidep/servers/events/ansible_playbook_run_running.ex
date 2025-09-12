defmodule ArchiDep.Servers.Events.AnsiblePlaybookRunRunning do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :playbook,
    :host,
    :port,
    :user,
    :server,
    :group,
    :owner
  ]

  defstruct [
    :id,
    :playbook,
    :host,
    :port,
    :user,
    :server,
    :group,
    :owner
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          playbook: String.t(),
          host: String.t(),
          port: 1..65_535,
          user: String.t(),
          server: %{
            id: UUID.t(),
            name: String.t() | nil,
            username: String.t()
          },
          group: %{
            id: UUID.t(),
            name: String.t()
          },
          owner: %{
            id: UUID.t(),
            username: String.t() | nil,
            name: String.t() | nil,
            root: boolean()
          }
        }

  @spec new(AnsiblePlaybookRun.t()) :: t()
  def new(run) do
    %AnsiblePlaybookRun{
      id: id,
      playbook: playbook,
      server: server,
      host: host,
      port: port,
      user: user
    } = run

    %Server{
      id: server_id,
      name: server_name,
      username: username,
      group: group,
      owner: owner
    } = server

    %ServerGroup{
      id: group_id,
      name: group_name
    } = group

    %ServerOwner{
      id: owner_id,
      username: owner_username,
      group_member: group_member,
      root: owner_root
    } = owner

    owner_name =
      case group_member do
        %ServerGroupMember{name: name} -> name
        nil -> nil
      end

    %__MODULE__{
      id: id,
      playbook: playbook,
      host: host.address |> :inet.ntoa() |> to_string(),
      port: port,
      user: user,
      server: %{
        id: server_id,
        name: server_name,
        username: username
      },
      group: %{
        id: group_id,
        name: group_name
      },
      owner: %{
        id: owner_id,
        username: owner_username,
        name: owner_name,
        root: owner_root
      }
    }
  end

  defimpl Event do
    alias ArchiDep.Servers.Events.AnsiblePlaybookRunRunning

    @spec event_stream(AnsiblePlaybookRunRunning.t()) :: String.t()
    def event_stream(%AnsiblePlaybookRunRunning{server: %{id: server_id}}),
      do: "servers:servers:#{server_id}"

    @spec event_type(AnsiblePlaybookRunRunning.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/ansible-playbook-run-running"
  end
end
