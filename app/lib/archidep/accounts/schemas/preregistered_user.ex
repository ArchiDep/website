defmodule ArchiDep.Accounts.Schemas.PreregisteredUser do
  @moduledoc """
  A preregistered user account which grants someone the right to log in to the
  application. The actual user account is created automatically when the person
  logs in with the corresponding email, at which point the preregistered user is
  linked to the user account.
  """

  use ArchiDep, :schema

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserGroup

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
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
    field(:name, :string)
    field(:active, :boolean, default: false)
    belongs_to(:group, UserGroup, source: :class_id)
    belongs_to(:user_account, UserAccount)
    field(:version, :integer)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: active, group: group}, now),
    do: active and UserGroup.active?(group, now)

  @spec event_stream(t()) :: String.t()
  def event_stream(%__MODULE__{id: id}), do: "accounts:preregistered-users:#{id}"

  @spec fetch_preregistered_user(UUID.t()) :: {:ok, t()} | {:error, :preregistered_user_not_found}
  def fetch_preregistered_user(preregistered_user_id),
    do:
      from(pu in __MODULE__,
        where: pu.id == ^preregistered_user_id,
        join: pug in assoc(pu, :group),
        left_join: pua in assoc(pu, :user_account),
        preload: [group: pug, user_account: pua]
      )
      |> Repo.one()
      |> truthy_or(:preregistered_user_not_found)

  @spec list_available_preregistered_users_for_emails(
          list(String.t()),
          DateTime.t()
        ) ::
          list(t())
  def list_available_preregistered_users_for_emails(emails, now) do
    lowercase_emails = Enum.map(emails, &String.downcase/1)

    Repo.all(
      from(pu in __MODULE__,
        join: ug in assoc(pu, :group),
        left_join: ua in assoc(pu, :user_account),
        where:
          pu.active and
            ug.active and (is_nil(ug.start_date) or ug.start_date <= ^now) and
            (is_nil(ug.end_date) or ug.end_date >= ^now) and
            (is_nil(ua) or is_nil(ua.switch_edu_id_id)) and
            fragment("LOWER(?)", pu.email) in ^lowercase_emails,
        preload: [group: ug, user_account: ua]
      )
    )
  end

  @spec link_to_user_account(
          t(),
          UserAccount.t(),
          DateTime.t()
        ) :: Changeset.t(t())
  def link_to_user_account(
        %__MODULE__{user_account_id: user_account_id} = preregistered_user,
        %UserAccount{id: user_account_id},
        _now
      ),
      do: change(preregistered_user)

  def link_to_user_account(
        %__MODULE__{user_account_id: nil} = preregistered_user,
        user_account,
        now
      ),
      do:
        preregistered_user
        |> change()
        |> put_assoc(:user_account, user_account)
        |> assoc_constraint(:user_account)
        |> change(updated_at: now)
        |> optimistic_lock(:version)
end
