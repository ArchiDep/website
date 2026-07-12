defmodule ArchiDep.Servers.ServerView do
  @moduledoc """
  Curated read model of a server for the web layer. It is the persistence
  aggregate (`ArchiDep.Servers.Schemas.Server`) minus `secret_key` (a
  server-side-only signing secret the web never reads) and the fields no page
  renders, with the nested `group` / `owner` reusing the existing curated
  read-views.

  `refresh!/3` applies a curated domain event to the in-memory projection: a
  server event updates the server-level fields, a class event refreshes the
  nested `group`, and a student event refreshes the nested `owner.group_member`,
  so a single call keeps the whole projection current regardless of which source
  aggregate changed.
  """

  import ArchiDep.Helpers.SchemaHelpers
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Events.ServerFactsGathered
  alias ArchiDep.Servers.Events.ServerOpenPortsChecked
  alias ArchiDep.Servers.Events.ServerSetUp
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias Ecto.UUID

  @enforce_keys [
    :id,
    :name,
    :ip_address,
    :username,
    :app_username,
    :ssh_port,
    :ssh_host_key_fingerprints,
    :active,
    :group,
    :group_id,
    :owner,
    :owner_id,
    :expected_properties,
    :version,
    :created_at,
    :set_up_at
  ]
  defstruct [
    :id,
    :name,
    :ip_address,
    :username,
    :app_username,
    :ssh_port,
    :ssh_host_key_fingerprints,
    :active,
    :group,
    :group_id,
    :owner,
    :owner_id,
    :expected_properties,
    :version,
    :created_at,
    :set_up_at
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: Postgrex.INET.t(),
          username: String.t(),
          app_username: String.t(),
          ssh_port: 1..65_535 | nil,
          ssh_host_key_fingerprints: String.t(),
          active: boolean(),
          group: ServerGroup.t(),
          group_id: UUID.t(),
          owner: ServerOwner.t(),
          owner_id: UUID.t(),
          expected_properties: ServerProperties.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          set_up_at: DateTime.t() | nil
        }

  @server_events [ServerUpdated, ServerFactsGathered, ServerSetUp, ServerOpenPortsChecked]
  @class_events [ClassUpdated, ClassExpectedServerPropertiesUpdated]
  @student_events [StudentUpdated, StudentConfigured]

  @doc """
  Builds a curated `ServerView` from a fully-loaded server aggregate, dropping
  `secret_key` and the fields no page renders.
  """
  @spec from(Server.t()) :: t()
  def from(%Server{} = server),
    do: %__MODULE__{
      id: server.id,
      name: server.name,
      ip_address: server.ip_address,
      username: server.username,
      app_username: server.app_username,
      ssh_port: server.ssh_port,
      ssh_host_key_fingerprints: server.ssh_host_key_fingerprints,
      active: server.active,
      group: server.group,
      group_id: server.group_id,
      owner: server.owner,
      owner_id: server.owner_id,
      expected_properties: server.expected_properties,
      version: server.version,
      created_at: server.created_at,
      set_up_at: server.set_up_at
    }

  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, group: group, owner: owner}, now),
    do:
      active and ServerGroup.active?(group, now) and ServerOwner.active?(owner, now) and
        (owner.group_member == nil or owner.group_member.group_id == group.id)

  @spec set_up?(t()) :: boolean()
  def set_up?(%__MODULE__{set_up_at: set_up_at}), do: set_up_at != nil

  @spec name_or_default(t()) :: String.t()
  def name_or_default(%__MODULE__{name: nil} = server), do: ssh_connection_description(server)
  def name_or_default(%__MODULE__{name: name}), do: name

  @spec ssh_connection_description(t()) :: String.t()
  def ssh_connection_description(%__MODULE__{
        ip_address: ip_address,
        username: username,
        ssh_port: ssh_port
      })
      when is_nil(ssh_port) or ssh_port == 22,
      do: "#{username}@#{:inet.ntoa(ip_address.address)}"

  def ssh_connection_description(%__MODULE__{
        ip_address: ip_address,
        username: username,
        ssh_port: ssh_port
      }),
      do: "#{username}@#{:inet.ntoa(ip_address.address)}:#{ssh_port}"

  @spec default_hostname(t()) :: String.t() | nil
  def default_hostname(%__MODULE__{
        username: username,
        owner: %ServerOwner{group_member: %ServerGroupMember{domain: domain}}
      }),
      do: "#{username}.#{domain}"

  def default_hostname(_server), do: nil

  @spec changed?(t(), t(), list(atom())) :: boolean()
  def changed?(
        %__MODULE__{group_id: group_id, owner_id: owner_id} = a,
        %__MODULE__{group_id: group_id, owner_id: owner_id} = b,
        fields
      )
      when is_list(fields),
      do:
        Enum.any?(fields, fn
          :expected_properties ->
            ServerProperties.changed?(a.expected_properties, b.expected_properties)

          :ssh_port ->
            Map.get(a, :ssh_port, 22) != Map.get(b, :ssh_port, 22)

          field ->
            Map.get(a, field) != Map.get(b, field)
        end)

  @spec refresh!(
          t(),
          ServerUpdated.t()
          | ServerFactsGathered.t()
          | ServerSetUp.t()
          | ServerOpenPortsChecked.t()
          | ClassUpdated.t()
          | ClassExpectedServerPropertiesUpdated.t()
          | StudentUpdated.t()
          | StudentConfigured.t(),
          EventReference.t()
        ) :: t()
  def refresh!(
        %__MODULE__{} = view,
        %event_module{} = event,
        %EventReference{version: version, occurred_at: occurred_at}
      )
      when event_module in @server_events,
      do:
        versioned_refresh(
          view,
          event,
          version,
          &fetch/1,
          &merge_server(&1, &2, version, occurred_at)
        )

  def refresh!(
        %__MODULE__{group: %ServerGroup{} = group} = view,
        %event_module{} = event,
        %EventReference{} = reference
      )
      when event_module in @class_events,
      do: %__MODULE__{view | group: ServerGroup.refresh!(group, event, reference)}

  def refresh!(
        %__MODULE__{owner: %ServerOwner{group_member: %ServerGroupMember{} = member} = owner} =
          view,
        %event_module{} = event,
        %EventReference{} = reference
      )
      when event_module in @student_events,
      do: %__MODULE__{
        view
        | owner: %ServerOwner{
            owner
            | group_member: ServerGroupMember.refresh!(member, event, reference)
          }
      }

  defp fetch(id) do
    case Server.fetch_server(id) do
      {:ok, server} -> {:ok, from(server)}
      {:error, _reason} = error -> error
    end
  end

  defp merge_server(
         %__MODULE__{id: id, expected_properties: expected_properties} = view,
         %ServerUpdated{
           id: id,
           name: name,
           ip_address: ip_address,
           username: username,
           app_username: app_username,
           ssh_port: ssh_port,
           ssh_host_key_fingerprints: ssh_host_key_fingerprints,
           active: active,
           expected_properties: %{
             hostname: hostname,
             machine_id: machine_id,
             cpus: cpus,
             cores: cores,
             vcpus: vcpus,
             memory: memory,
             swap: swap,
             system: system,
             architecture: architecture,
             os_family: os_family,
             distribution: distribution,
             distribution_release: distribution_release,
             distribution_version: distribution_version
           }
         },
         version,
         _occurred_at
       ),
       do: %__MODULE__{
         view
         | name: name,
           ip_address: parse_ip_address(ip_address),
           username: username,
           app_username: app_username,
           ssh_port: ssh_port,
           ssh_host_key_fingerprints: ssh_host_key_fingerprints,
           active: active,
           expected_properties:
             ServerProperties.refresh(expected_properties, %{
               id: expected_properties.id,
               hostname: hostname,
               machine_id: machine_id,
               cpus: cpus,
               cores: cores,
               vcpus: vcpus,
               memory: memory,
               swap: swap,
               system: system,
               architecture: architecture,
               os_family: os_family,
               distribution: distribution,
               distribution_release: distribution_release,
               distribution_version: distribution_version
             }),
           version: version
       }

  defp merge_server(%__MODULE__{id: id} = view, %ServerSetUp{id: id}, version, set_up_at),
    do: %__MODULE__{view | set_up_at: set_up_at, version: version}

  defp merge_server(
         %__MODULE__{id: id} = view,
         %ServerFactsGathered{id: id},
         version,
         _occurred_at
       ),
       do: %__MODULE__{view | version: version}

  defp merge_server(
         %__MODULE__{id: id} = view,
         %ServerOpenPortsChecked{id: id},
         version,
         _occurred_at
       ),
       do: %__MODULE__{view | version: version}

  defp merge_server(_view, _incoming, _version, _occurred_at), do: :refetch

  defp parse_ip_address(ip_address) do
    {:ok, address} = ip_address |> to_charlist() |> :inet.parse_address()
    %Postgrex.INET{address: address}
  end
end
