defmodule ArchiDep.Servers.Schemas.Server do
  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Servers.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: :inet.ip_address(),
          username: String.t(),
          user_account: UserAccount.t() | nil | NotLoaded,
          user_account_id: UUID.t() | nil,
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

  @spec new(Types.create_server_data()) :: Changeset.t(t())
  def new(data) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [:name, :ip_address, :username, :user_account_id])
    |> change(
      id: id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate_length(:name, max: 50)
    |> validate_format(:name, ~r/\A\S.*\z/, message: "must not start with whitespace")
    |> validate_format(:name, ~r/\A.*\S\z/, message: "must not end with whitespace")
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
