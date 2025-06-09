defmodule ArchiDep.Accounts.Schemas.UserAccount do
  @moduledoc """
  A user account for someone who can log in to the application. The user may be
  an administrator or not.
  """

  use ArchiDep, :schema

  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Types

  @derive {Inspect, only: [:id, :username, :roles, :version]}
  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t(),
          roles: list(Types.role()),
          switch_edu_id: SwitchEduId.t() | NotLoaded,
          switch_edu_id_id: UUID.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @max_username_length 25

  schema "user_accounts" do
    field(:username, :string)
    field(:roles, {:array, Ecto.Enum}, values: [:root, :student])
    belongs_to(:switch_edu_id, SwitchEduId)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec student?(__MODULE__.t()) :: boolean
  def student?(%__MODULE__{roles: roles}), do: :student in roles

  @spec fetch_or_create_for_switch_edu_id(SwitchEduId.t(), list(Types.role())) ::
          {:existing_account, Changeset.t(t())} | {:new_account, Changeset.t(t())}
  def fetch_or_create_for_switch_edu_id(switch_edu_id, roles) do
    if existing_account = fetch_for_switch_edu_id(switch_edu_id) do
      {:existing_account, change(existing_account)}
    else
      {:new_account, new_switch_edu_id_account(switch_edu_id, roles)}
    end
  end

  @spec get_with_switch_edu_id!(UUID.t()) :: t
  def get_with_switch_edu_id!(id),
    do:
      from(ua in __MODULE__,
        join: sei in SwitchEduId,
        on: ua.switch_edu_id_id == sei.id,
        where: ua.id == ^id,
        preload: [switch_edu_id: sei]
      )
      |> Repo.one!()

  @spec event_stream(String.t() | __MODULE__.t()) :: String.t()
  def event_stream(id) when is_binary(id), do: "user-accounts:#{id}"
  def event_stream(%__MODULE__{id: id}), do: event_stream(id)

  @spec fetch_for_switch_edu_id(SwitchEduId.t()) :: t() | nil
  def fetch_for_switch_edu_id(%SwitchEduId{id: switch_edu_id_id}),
    do:
      Repo.one(
        from(ua in __MODULE__,
          join: sei in SwitchEduId,
          on: ua.switch_edu_id_id == sei.id,
          where: sei.id == ^switch_edu_id_id,
          preload: [switch_edu_id: sei]
        )
      )

  @spec new_switch_edu_id_account(SwitchEduId.t(), list(Types.role())) :: Changeset.t(t())
  def new_switch_edu_id_account(switch_edu_id, roles) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(
      %{
        username: switch_edu_id.first_name || String.replace(switch_edu_id.email, ~r/@.*/, ""),
        roles: roles
      },
      [
        :username,
        :roles
      ]
    )
    |> change(
      id: id,
      switch_edu_id_id: switch_edu_id.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
  end

  defp validate(changeset),
    do:
      changeset
      |> update_change(:username, &String.trim/1)
      |> validate_required([
        :id,
        :username,
        :roles,
        :version,
        :created_at,
        :updated_at
      ])
      |> validate_length(:username, max: @max_username_length)
      |> validate_subset(:roles, [:root, :student])
      |> unique_constraint(:username, name: :user_accounts_unique_username_index)
end
