defmodule ArchiDep.Servers.Events.ServerGroupMemberConfigured do
  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.ServerGroupMember

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :username
  ]
  defstruct [
    :id,
    :username
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t()
        }

  @spec new(ServerGroupMember.t()) :: t()
  def new(member) do
    %ServerGroupMember{
      id: id,
      username: username
    } = member

    %__MODULE__{
      id: id,
      username: username
    }
  end

  defimpl Event do
    alias ArchiDep.Servers.Events.ServerGroupMemberConfigured

    def event_stream(%ServerGroupMemberConfigured{id: id}),
      do: "servers:server-group-members:#{id}"

    def event_type(_event), do: :"archidep/servers/server-group-member-configured"
  end
end
