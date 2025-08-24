defmodule ArchiDep.Servers.Schemas.Server do
  @moduledoc """
  A server tracked by the application. A persistent SSH connection is
  established to the server to run Ansible playbooks and track its state. If the
  connection drops, the application will attempt to reconnect to the server.

  The application initially connects to the server with the IP address and
  username provided by the user who created the server. Once initial setup (an
  Ansible playbook) is complete, the application disconnects and then reconnects
  with its own username.
  """

  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  import ArchiDep.Servers.Schemas.ServerOwner, only: [where_server_owner_active: 1]
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  # TODO: store number of consecutive failed connection attemps

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: Postgrex.INET.t(),
          username: String.t(),
          app_username: String.t(),
          ssh_port: 1..65_535 | nil,
          secret_key: binary(),
          active: boolean(),
          group: ServerGroup.t() | NotLoaded.t(),
          group_id: UUID.t(),
          owner: ServerOwner.t() | NotLoaded.t(),
          owner_id: UUID.t(),
          expected_properties: ServerProperties.t() | NotLoaded.t(),
          expected_properties_id: UUID.t(),
          last_known_properties: ServerProperties.t() | nil | NotLoaded.t(),
          last_known_properties_id: UUID.t() | nil,
          # Common metadata
          version: pos_integer(),
          created_at: DateTime.t(),
          set_up_at: DateTime.t() | nil,
          open_ports_checked_at: DateTime.t() | nil,
          updated_at: DateTime.t()
        }

  schema "servers" do
    field(:name, :string)
    field(:ip_address, EctoNetwork.INET)
    field(:username, :string)
    field(:app_username, :string)
    field(:ssh_port, :integer)
    field(:secret_key, :binary)
    field(:active, :boolean)
    belongs_to(:group, ServerGroup, source: :class_id)
    belongs_to(:owner, ServerOwner, source: :user_account_id)
    belongs_to(:expected_properties, ServerProperties)
    belongs_to(:last_known_properties, ServerProperties)
    # Common metadata
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:set_up_at, :utc_datetime_usec)
    field(:open_ports_checked_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  # TODO: track changes to the group and owner
  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, group: group, owner: owner}, now),
    do:
      active and ServerGroup.active?(group, now) and ServerOwner.active?(owner, now) and
        (owner.group_member == nil or owner.group_member.group_id == group.id)

  @spec name_or_default(t()) :: String.t()
  def name_or_default(%__MODULE__{name: nil} = server), do: default_name(server)
  def name_or_default(%__MODULE__{name: name}), do: name

  @spec default_name(t()) :: String.t()
  def default_name(%__MODULE__{ip_address: ip_address, username: username}),
    do: "#{username}@#{:inet.ntoa(ip_address.address)}"

  @spec list_active_servers(DateTime.t()) :: list(t())
  def list_active_servers(now) do
    day = DateTime.to_date(now)

    where =
      dynamic(
        [s, owner_group_member: ogm, owner_group: og, server_group: sg],
        s.active and (is_nil(og) or og.id == sg.id) and ^where_server_owner_active(day)
      )

    Repo.all(
      from(s in __MODULE__,
        distinct: true,
        join: o in assoc(s, :owner),
        as: :owner,
        left_join: ogm in assoc(o, :group_member),
        as: :owner_group_member,
        left_join: og in assoc(ogm, :group),
        as: :owner_group,
        join: sg in assoc(s, :group),
        as: :server_group,
        join: sgesp in assoc(sg, :expected_server_properties),
        join: ep in assoc(s, :expected_properties),
        left_join: lkp in assoc(s, :last_known_properties),
        where: ^where,
        preload: [
          group: {sg, expected_server_properties: sgesp},
          expected_properties: ep,
          last_known_properties: lkp,
          owner: {o, group_member: {ogm, group: og}}
        ]
      )
    )
  end

  @spec count_active_servers(DateTime.t()) :: non_neg_integer()
  def count_active_servers(now) do
    day = DateTime.to_date(now)

    where =
      dynamic(
        [s, owner_group_member: ogm, owner_group: og, server_group: sg],
        s.active and (is_nil(og) or og.id == sg.id) and ^where_server_owner_active(day)
      )

    Repo.aggregate(
      from(s in __MODULE__,
        distinct: true,
        join: o in assoc(s, :owner),
        as: :owner,
        left_join: ogm in assoc(o, :group_member),
        as: :owner_group_member,
        left_join: og in assoc(ogm, :group),
        as: :owner_group,
        join: sg in assoc(s, :group),
        as: :server_group,
        join: sgesp in assoc(sg, :expected_server_properties),
        join: ep in assoc(s, :expected_properties),
        left_join: lkp in assoc(s, :last_known_properties),
        where: ^where,
        preload: [
          group: {sg, expected_server_properties: sgesp},
          expected_properties: ep,
          last_known_properties: lkp,
          owner: {o, group_member: {ogm, group: og}}
        ]
      ),
      :count,
      :id
    )
  end

  @spec list_server_ids_in_group(UUID.t()) :: list(UUID.t())
  def list_server_ids_in_group(group_id),
    do:
      Repo.all(
        from(s in __MODULE__,
          select: s.id,
          where: s.group_id == ^group_id
        )
      )

  @spec fetch_server(UUID.t()) :: {:ok, t()} | {:error, :server_not_found}
  def fetch_server(id),
    do:
      from(s in __MODULE__,
        join: o in assoc(s, :owner),
        left_join: ogm in assoc(o, :group_member),
        left_join: ogmg in assoc(ogm, :group),
        join: g in assoc(s, :group),
        join: gesp in assoc(g, :expected_server_properties),
        join: ep in assoc(s, :expected_properties),
        left_join: lkp in assoc(s, :last_known_properties),
        where: s.id == ^id,
        preload: [
          group: {g, expected_server_properties: gesp},
          expected_properties: ep,
          last_known_properties: lkp,
          owner: {o, group_member: {ogm, group: ogmg}}
        ]
      )
      |> Repo.one()
      |> truthy_or(:server_not_found)

  @spec new(Types.create_server_data(), ServerOwner.t()) :: Changeset.t(t())
  def new(data, owner) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active,
      :group_id,
      :app_username
    ])
    |> cast_assoc(:expected_properties, with: &ServerProperties.new(&1, id, &2))
    |> change(
      id: id,
      secret_key: :crypto.strong_rand_bytes(50),
      owner_id: owner.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate_new_server()
  end

  @spec new_group_member_server(Types.create_server_data(), ServerOwner.t()) ::
          Changeset.t(t())
  def new_group_member_server(data, owner) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active
    ])
    |> cast_assoc(:expected_properties,
      with: fn _struct, _params -> ServerProperties.blank_changeset(id) end
    )
    |> change(
      id: id,
      secret_key: :crypto.strong_rand_bytes(50),
      owner_id: owner.id,
      group_id: owner.group_member.group_id,
      app_username: "archidep",
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate_new_server()
    |> validate_change(:active, fn :active, active ->
      if active and ServerOwner.active_server_limit_reached?(owner) do
        [
          active:
            {"active server limit reached (max {current})",
             current: owner.active_server_count, limit: ServerOwner.active_server_limit()}
        ]
      else
        []
      end
    end)
  end

  @spec update(t(), Types.update_server_data()) :: Changeset.t(t())
  def update(server, data) do
    id = server.id
    now = DateTime.utc_now()

    data = Map.put(data, :expected_properties, Map.put(data.expected_properties, :id, id))

    server
    |> cast(data, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :app_username,
      :active
    ])
    |> cast_assoc(:expected_properties, with: &ServerProperties.update/2)
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate_existing_server(id)
  end

  @spec update_group_member_server(t(), Types.update_server_data(), ServerOwner.t()) ::
          Changeset.t(t())
  def update_group_member_server(server, data, owner) do
    id = server.id
    now = DateTime.utc_now()

    server
    |> cast(data, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active
    ])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate_existing_server(id)
    |> validate_change(:active, fn :active, active ->
      if active and ServerOwner.active_server_limit_reached?(owner) do
        [
          active:
            {"active server limit reached (max {current})",
             current: owner.active_server_count, limit: ServerOwner.active_server_limit()}
        ]
      else
        []
      end
    end)
  end

  @spec update_last_known_properties!(t(), map()) :: t()
  def update_last_known_properties!(server, ansible_facts) do
    server
    |> change(
      last_known_properties:
        ServerProperties.update_from_ansible_facts(
          server.last_known_properties || %ServerProperties{id: UUID.generate()},
          ansible_facts
        )
    )
    |> optimistic_lock(:version)
    |> Repo.update!()
  end

  @spec mark_as_set_up!(t()) :: t()
  def mark_as_set_up!(%__MODULE__{set_up_at: nil} = server) do
    now = DateTime.utc_now()

    server
    |> change(set_up_at: now)
    |> optimistic_lock(:version)
    |> Repo.update!()
  end

  @spec mark_open_ports_checked!(t()) :: t()
  def mark_open_ports_checked!(%__MODULE__{open_ports_checked_at: nil} = server) do
    now = DateTime.utc_now()

    server
    |> change(open_ports_checked_at: now)
    |> optimistic_lock(:version)
    |> Repo.update!()
  end

  defp validate_new_server(changeset) do
    changeset
    |> validate()
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)
      group_id = get_field(changeset, :group_id)

      from(s in __MODULE__,
        where: s.name == ^name and s.group_id == ^group_id
      )
    end)
    |> unsafe_validate_unique_query(:ip_address, Repo, fn changeset ->
      ip_address = get_field(changeset, :ip_address)

      from(s in __MODULE__,
        where: s.ip_address == ^ip_address
      )
    end)
  end

  defp validate_existing_server(changeset, id) do
    changeset
    |> validate_required([:expected_properties_id])
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)
      group_id = get_field(changeset, :group_id)

      from(s in __MODULE__,
        where: s.id != ^id and s.name == ^name and s.group_id == ^group_id
      )
    end)
    |> unsafe_validate_unique_query(:ip_address, Repo, fn changeset ->
      ip_address = get_field(changeset, :ip_address)

      from(s in __MODULE__,
        where: s.id != ^id and s.ip_address == ^ip_address
      )
    end)
  end

  defp validate(changeset) do
    changeset
    |> update_change(:name, &trim_to_nil/1)
    |> update_change(:username, &trim/1)
    |> update_change(:app_username, &trim/1)
    |> validate_required([
      :ip_address,
      :username,
      :secret_key,
      :active,
      :group_id,
      :app_username,
      :expected_properties
    ])
    |> validate_length(:name, max: 50)
    |> unique_constraint(:name)
    |> validate_length(:username, max: 32)
    |> validate_number(:ssh_port, greater_than: 0, less_than: 65_536)
    |> unique_constraint(:ip_address)
    |> assoc_constraint(:owner)
    |> validate_length(:app_username, max: 32)
    |> validate_username_and_app_username()
  end

  defp validate_username_and_app_username(changeset) do
    if changed?(changeset, :username) or changed?(changeset, :app_username) do
      validate_username_and_app_username(
        changeset,
        get_field(changeset, :username),
        get_field(changeset, :app_username)
      )
    else
      changeset
    end
  end

  defp validate_username_and_app_username(changeset, username, app_username)
       when username != nil and username == app_username,
       do: add_error(changeset, :app_username, "cannot be the same as the username")

  defp validate_username_and_app_username(changeset, _username, _app_username), do: changeset
end
