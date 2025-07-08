defmodule ArchiDep.Accounts.Schemas.PreregisteredUser do
  use ArchiDep, :schema

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserGroup

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          email: String.t(),
          active: boolean(),
          group: UserGroup.t() | NotLoaded.t(),
          group_id: UUID.t(),
          user_account: UserAccount.t() | nil | NotLoaded.t(),
          user_account_id: UUID.t() | nil,
          version: pos_integer(),
          updated_at: DateTime.t()
        }

  schema "students" do
    field(:email, :string)
    field(:active, :boolean, default: false)
    belongs_to(:group, UserGroup, source: :class_id)
    belongs_to(:user_account, UserAccount)
    field(:version, :integer)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: active, group: group}, now),
    do: active and UserGroup.active?(group, now)

  @spec list_available_preregistered_users_for_email(String.t(), DateTime.t()) :: list(t())
  def list_available_preregistered_users_for_email(email, now) do
    from(pu in __MODULE__,
      join: ug in assoc(pu, :group),
      where:
        pu.active and
          ug.active and (is_nil(ug.start_date) or ug.start_date <= ^now) and
          (is_nil(ug.end_date) or ug.end_date >= ^now) and is_nil(pu.user_account_id) and
          fragment("LOWER(?)", pu.email) == fragment("LOWER(?)", ^email),
      preload: [group: ug]
    )
    |> Repo.all()
  end

  @spec link_to_user_account(
          t(),
          UserAccount.t()
        ) :: Changeset.t(t())
  def link_to_user_account(%__MODULE__{user_account_id: nil} = preregistered_user, user_account) do
    now = DateTime.utc_now()

    preregistered_user
    |> cast(%{user_account_id: user_account.id}, [:user_account_id])
    |> assoc_constraint(:user_account)
    |> change(updated_at: now)
    |> optimistic_lock(:version)
  end
end
