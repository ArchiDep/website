defmodule ArchiDep.Servers.Events.AnsiblePlaybookRunStarted do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Types
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :playbook,
    :playbook_path,
    :digest,
    :git_revision,
    :host,
    :port,
    :user,
    :vars,
    :server,
    :group,
    :owner
  ]
  defstruct [
    :id,
    :playbook,
    :playbook_path,
    :digest,
    :git_revision,
    :host,
    :port,
    :user,
    :vars,
    :server,
    :group,
    :owner
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          playbook: String.t(),
          playbook_path: String.t(),
          digest: String.t(),
          git_revision: String.t(),
          host: String.t(),
          port: 1..65_535,
          user: String.t(),
          vars: Types.ansible_variables(),
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
      playbook_path: playbook_path,
      digest: digest,
      git_revision: git_revision,
      host: host,
      port: port,
      user: user,
      vars: vars,
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
      playbook: playbook,
      playbook_path: playbook_path,
      digest: Base.encode16(digest, case: :lower),
      git_revision: git_revision,
      host: host.address |> :inet.ntoa() |> to_string(),
      port: port,
      user: user,
      vars: vars,
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
    alias ArchiDep.Servers.Events.AnsiblePlaybookRunStarted

    @spec event_stream(AnsiblePlaybookRunStarted.t()) :: String.t()
    def event_stream(%AnsiblePlaybookRunStarted{server: %{id: server_id}}),
      do: "servers:servers:#{server_id}"

    @spec event_type(AnsiblePlaybookRunStarted.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/ansible-playbook-run-started"
  end
end
