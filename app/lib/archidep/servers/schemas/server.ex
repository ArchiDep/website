defmodule ArchiDep.Servers.Schemas.Server do
  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Servers.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  # TODO: add optional custom SSH port
  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: Postgrex.INET.t(),
          username: String.t(),
          user_account: UserAccount.t() | nil | NotLoaded,
          user_account_id: UUID.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "servers" do
    field(:name, :string)
    field(:ip_address, EctoNetwork.INET)
    field(:username, :string)
    belongs_to(:user_account, UserAccount)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec list_active_servers() :: list(t())
  def list_active_servers do
    Repo.all(
      from(s in __MODULE__,
        distinct: true,
        join: ua in UserAccount,
        on: s.user_account_id == ua.id,
        left_join: st in Student,
        on: ua.id == st.user_account_id,
        left_join: c in Class,
        on: st.class_id == c.id,
        # TODO: put query fragment determining whether auser is active in the user account schema
        where: :root in ua.roles or c.active == true,
        preload: [user_account: ua]
      )
    )
  end

  @spec fetch_server(UUID.t()) :: {:ok, t()} | {:error, :server_not_found}
  def fetch_server(id) do
    case Repo.get(__MODULE__, id) do
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
    |> cast(data, [:name, :ip_address, :username])
    |> change(
      id: id,
      user_account_id: user.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> update_change(:name, &String.trim/1)
    |> update_change(:username, &String.trim/1)
    |> validate_length(:name, max: 50)
    |> validate_length(:username, max: 32)
    |> validate_required([:ip_address, :username])
    |> unique_constraint(:ip_address)
    |> unsafe_validate_unique_query(:ip_address, Repo, fn changeset ->
      ip_address = get_field(changeset, :ip_address)

      from(s in __MODULE__,
        where: s.ip_address == ^ip_address
      )
    end)
    |> assoc_constraint(:user_account)
  end
end
