defmodule ArchiDep.Servers.Schemas.Server do
  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Students.Schemas.Class
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
          shared_secret: binary(),
          active: boolean(),
          class: Class.t() | NotLoaded,
          class_id: UUID.t(),
          user_account: UserAccount.t() | NotLoaded,
          user_account_id: UUID.t(),
          expected_properties: ServerProperties.t() | NotLoaded,
          expected_properties_id: UUID.t(),
          # Common metadata
          version: pos_integer(),
          created_at: DateTime.t(),
          set_up_at: DateTime.t() | nil,
          updated_at: DateTime.t()
        }

  schema "servers" do
    field(:name, :string)
    field(:ip_address, EctoNetwork.INET)
    field(:username, :string)
    field(:app_username, :string)
    field(:ssh_port, :integer)
    field(:shared_secret, :binary)
    field(:active, :boolean)
    belongs_to(:class, Class)
    belongs_to(:user_account, UserAccount)
    belongs_to(:expected_properties, ServerProperties)
    # Common metadata
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:set_up_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  # FIXME: track changes to the user account
  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{active: active, class: class, user_account: user_account}, now),
    do:
      active and Class.active?(class, now) and UserAccount.active?(user_account, now) and
        (Enum.member?(user_account.roles, :root) or
           (Enum.member?(user_account.roles, :student) and user_account.student != nil and
              user_account.student.class_id == class.id))

  @spec name_or_default(t()) :: String.t()
  def name_or_default(%__MODULE__{name: nil} = server), do: default_name(server)
  def name_or_default(%__MODULE__{name: name}), do: name

  @spec default_name(__MODULE__.t()) :: String.t()
  def default_name(%__MODULE__{ip_address: ip_address, username: username}),
    do: "#{username}@#{:inet.ntoa(ip_address.address)}"

  @spec list_active_servers(DateTime.t()) :: list(t())
  def list_active_servers(now) do
    day = DateTime.to_date(now)

    Repo.all(
      from(s in __MODULE__,
        distinct: true,
        join: ua in assoc(s, :user_account),
        left_join: uas in assoc(ua, :student),
        join: c in assoc(s, :class),
        join: ep in assoc(s, :expected_properties),
        # TODO: put query fragment determining whether a user is active in the user account schema
        where:
          s.active and ua.active and
            (:root in ua.roles or
               (uas.active and uas.class_id == c.id and c.active == true and
                  (is_nil(c.start_date) or c.start_date <= ^day) and
                  (is_nil(c.end_date) or c.end_date >= ^day))),
        preload: [class: c, expected_properties: ep, user_account: ua]
      )
    )
  end

  @spec fetch_server(UUID.t()) :: {:ok, t()} | {:error, :server_not_found}
  def fetch_server(id) do
    case Repo.one(
           from(s in __MODULE__,
             join: c in assoc(s, :class),
             join: ua in assoc(s, :user_account),
             left_join: uas in assoc(ua, :student),
             left_join: uac in assoc(uas, :class),
             join: ep in assoc(s, :expected_properties),
             where: s.id == ^id,
             preload: [
               class: c,
               expected_properties: ep,
               user_account: {ua, student: {uas, class: uac}}
             ]
           )
         ) do
      nil ->
        {:error, :server_not_found}

      server ->
        {:ok, server}
    end
  end

  @spec new(Types.create_server_data(), UserAccount.t()) :: Changeset.t(t())
  def new(data, user) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active,
      :class_id,
      :app_username
    ])
    |> cast_assoc(:expected_properties, with: &ServerProperties.new(&1, id, &2))
    |> change(
      id: id,
      shared_secret: :crypto.strong_rand_bytes(50),
      user_account_id: user.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)
      class_id = get_field(changeset, :class_id)

      from(s in __MODULE__,
        where: s.name == ^name and s.class_id == ^class_id
      )
    end)
    |> unsafe_validate_unique_query(:ip_address, Repo, fn changeset ->
      ip_address = get_field(changeset, :ip_address)

      from(s in __MODULE__,
        where: s.ip_address == ^ip_address
      )
    end)
  end

  @spec update(t(), Types.update_server_data()) :: Changeset.t(t())
  def update(server, data) do
    id = server.id
    now = DateTime.utc_now()

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
    |> validate()
    |> validate_required([:expected_properties_id])
    |> unsafe_validate_unique_query(:name, Repo, fn changeset ->
      name = get_field(changeset, :name)
      class_id = get_field(changeset, :class_id)

      from(s in __MODULE__,
        where: s.id != ^id and s.name == ^name and s.class_id == ^class_id
      )
    end)
    |> unsafe_validate_unique_query(:ip_address, Repo, fn changeset ->
      ip_address = get_field(changeset, :ip_address)

      from(s in __MODULE__,
        where: s.id != ^id and s.ip_address == ^ip_address
      )
    end)
  end

  @spec mark_as_set_up!(t()) :: Changeset.t(t())
  def mark_as_set_up!(%__MODULE__{set_up_at: nil} = server) do
    now = DateTime.utc_now()

    server
    |> change(set_up_at: now)
    |> optimistic_lock(:version)
    |> Repo.update!()
  end

  defp validate(changeset) do
    changeset
    |> update_change(:name, &trim_to_nil/1)
    |> update_change(:username, &trim/1)
    |> update_change(:app_username, &trim/1)
    |> validate_required([
      :ip_address,
      :username,
      :shared_secret,
      :active,
      :class_id,
      :app_username,
      :expected_properties
    ])
    |> validate_length(:name, max: 50)
    |> unique_constraint(:name)
    |> validate_length(:username, max: 32)
    |> validate_number(:ssh_port, greater_than: 0, less_than: 65_536)
    |> unique_constraint(:ip_address)
    |> assoc_constraint(:user_account)
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
