defmodule ArchiDep.Servers.Events.AnsiblePlaybookEventOccurred do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :properties,
    :playbook_run,
    :server,
    :group,
    :owner
  ]

  defstruct [
    :id,
    :properties,
    :playbook_run,
    :server,
    :group,
    :owner
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          properties: %{String.t() => term()},
          playbook_run: %{
            id: UUID.t(),
            playbook: String.t()
          },
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

  @spec new(AnsiblePlaybookEvent.t()) :: t()
  def new(event) do
    %AnsiblePlaybookEvent{
      id: id,
      run: run,
      data: properties
    } = event

    %AnsiblePlaybookRun{
      id: run_id,
      playbook: playbook,
      server: server
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
      properties: properties,
      playbook_run: %{
        id: run_id,
        playbook: playbook
      },
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
    alias ArchiDep.Servers.Events.AnsiblePlaybookEventOccurred

    @spec event_stream(AnsiblePlaybookEventOccurred.t()) :: String.t()
    def event_stream(%AnsiblePlaybookEventOccurred{server: %{id: server_id}}),
      do: "servers:servers:#{server_id}"

    @spec event_type(AnsiblePlaybookEventOccurred.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/ansible-playbook-event-occurred"
  end
end
