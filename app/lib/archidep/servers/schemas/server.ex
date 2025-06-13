defmodule ArchiDep.Servers.Schemas.Server do
  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Students.Schemas.Class
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
          ssh_port: 1..65_535 | nil,
          class: Class.t() | NotLoaded,
          class_id: UUID.t(),
          user_account: UserAccount.t() | nil | NotLoaded,
          user_account_id: UUID.t(),
          # Expected properties for this server
          expected_cpus: non_neg_integer() | nil,
          expected_cores: non_neg_integer() | nil,
          expected_vcpus: non_neg_integer() | nil,
          expected_memory: non_neg_integer() | nil,
          expected_swap: non_neg_integer() | nil,
          expected_system: String.t() | nil,
          expected_architecture: String.t() | nil,
          expected_os_family: String.t() | nil,
          expected_distribution: String.t() | nil,
          expected_distribution_release: String.t() | nil,
          expected_distribution_version: String.t() | nil,
          # Common metadata
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "servers" do
    field(:name, :string)
    field(:ip_address, EctoNetwork.INET)
    field(:username, :string)
    field(:ssh_port, :integer)
    belongs_to(:class, Class)
    belongs_to(:user_account, UserAccount)
    # Expected properties for this server
    field(:expected_cpus, :integer)
    field(:expected_cores, :integer)
    field(:expected_vcpus, :integer)
    field(:expected_memory, :integer)
    field(:expected_swap, :integer)
    field(:expected_system, :string)
    field(:expected_architecture, :string)
    field(:expected_os_family, :string)
    field(:expected_distribution, :string)
    field(:expected_distribution_release, :string)
    field(:expected_distribution_version, :string)
    # Common metadata
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec name_or_default(__MODULE__.t()) :: String.t()
  def name_or_default(%__MODULE__{name: nil} = server), do: default_name(server)
  def name_or_default(%__MODULE__{name: name}), do: name

  @spec default_name(__MODULE__.t()) :: String.t()
  def default_name(%__MODULE__{ip_address: ip_address, username: username}),
    do: "#{username}@#{:inet.ntoa(ip_address.address)}"

  @spec list_active_servers() :: list(t())
  def list_active_servers do
    Repo.all(
      from(s in __MODULE__,
        distinct: true,
        join: ua in UserAccount,
        on: s.user_account_id == ua.id,
        join: c in Class,
        on: s.class_id == c.id,
        # TODO: put query fragment determining whether auser is active in the user account schema
        where: :root in ua.roles or c.active == true,
        preload: [class: c, user_account: ua]
      )
    )
  end

  @spec fetch_server(UUID.t()) :: {:ok, t()} | {:error, :server_not_found}
  def fetch_server(id) do
    case Repo.one(
           from(s in __MODULE__,
             join: c in Class,
             on: s.class_id == c.id,
             where: s.id == ^id,
             preload: [class: c]
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
      :class_id,
      :expected_cpus,
      :expected_cores,
      :expected_vcpus,
      :expected_memory,
      :expected_swap,
      :expected_system,
      :expected_architecture,
      :expected_os_family,
      :expected_distribution,
      :expected_distribution_release,
      :expected_distribution_version
    ])
    |> change(
      id: id,
      user_account_id: user.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
    |> unsafe_validate_unique_query(:ip_address, Repo, fn changeset ->
      ip_address = get_field(changeset, :ip_address)

      from(s in __MODULE__,
        where: s.ip_address == ^ip_address
      )
    end)
  end

  @spec update(__MODULE__.t(), Types.update_server_data()) :: Changeset.t(t())
  def update(server, data) do
    id = server.id
    now = DateTime.utc_now()

    server
    |> cast(data, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :expected_cpus,
      :expected_cores,
      :expected_vcpus,
      :expected_memory,
      :expected_swap,
      :expected_system,
      :expected_architecture,
      :expected_os_family,
      :expected_distribution,
      :expected_distribution_release,
      :expected_distribution_version
    ])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> validate()
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
    |> update_change(:expected_system, &trim_to_nil/1)
    |> update_change(:expected_architecture, &trim_to_nil/1)
    |> update_change(:expected_os_family, &trim_to_nil/1)
    |> update_change(:expected_distribution, &trim_to_nil/1)
    |> update_change(:expected_distribution_release, &trim_to_nil/1)
    |> update_change(:expected_distribution_version, &trim_to_nil/1)
    |> validate_required([:ip_address, :username, :class_id])
    |> validate_length(:name, max: 50)
    |> validate_length(:username, max: 32)
    |> validate_number(:ssh_port, greater_than: 0, less_than: 65_536)
    |> unique_constraint(:ip_address)
    |> assoc_constraint(:user_account)
    |> validate_number(:expected_cpus, greater_than_or_equal_to: 0, less_than_or_equal_to: 32_767)
    |> validate_number(:expected_cores,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 32_767
    )
    |> validate_number(:expected_vcpus,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 32_767
    )
    |> validate_number(:expected_memory,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647
    )
    |> validate_number(:expected_swap,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647
    )
    |> validate_length(:expected_system, max: 50)
    |> validate_length(:expected_architecture, max: 20)
    |> validate_length(:expected_os_family, max: 50)
    |> validate_length(:expected_distribution, max: 50)
    |> validate_length(:expected_distribution_release, max: 50)
    |> validate_length(:expected_distribution_version, max: 20)
  end
end
