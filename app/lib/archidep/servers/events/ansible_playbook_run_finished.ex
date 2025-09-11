defmodule ArchiDep.Servers.Events.AnsiblePlaybookRunFinished do
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
    :state,
    :number_of_events,
    :exit_code,
    :stats,
    :server,
    :group,
    :owner
  ]

  defstruct [
    :id,
    :playbook,
    :state,
    :number_of_events,
    :exit_code,
    :stats,
    :server,
    :group,
    :owner
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          playbook: String.t(),
          state: String.t(),
          number_of_events: non_neg_integer(),
          exit_code: 0..255,
          stats: %{
            changed: non_neg_integer(),
            failures: non_neg_integer(),
            ignored: non_neg_integer(),
            ok: non_neg_integer(),
            rescued: non_neg_integer(),
            skipped: non_neg_integer(),
            unreachable: non_neg_integer()
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

  @spec new(AnsiblePlaybookRun.t(), Server.t()) :: t()
  def new(run, server) do
    %AnsiblePlaybookRun{
      id: id,
      playbook: playbook,
      state: state,
      number_of_events: number_of_events,
      exit_code: exit_code,
      stats_changed: changed,
      stats_failures: failures,
      stats_ignored: ignored,
      stats_ok: ok,
      stats_rescued: rescued,
      stats_skipped: skipped,
      stats_unreachable: unreachable
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
      state: Atom.to_string(state),
      number_of_events: number_of_events,
      exit_code: exit_code,
      stats: %{
        changed: changed,
        failures: failures,
        ignored: ignored,
        ok: ok,
        rescued: rescued,
        skipped: skipped,
        unreachable: unreachable
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
    alias ArchiDep.Servers.Events.AnsiblePlaybookRunFinished

    @spec event_stream(AnsiblePlaybookRunFinished.t()) :: String.t()
    def event_stream(%AnsiblePlaybookRunFinished{server: %{id: server_id}}),
      do: "servers:servers:#{server_id}"

    @spec event_type(AnsiblePlaybookRunFinished.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/ansible-playbook-run-finished"
  end
end
