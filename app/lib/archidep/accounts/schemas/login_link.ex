defmodule ArchiDep.Accounts.Schemas.LoginLink do
  @moduledoc """
  A one-time login link that can be used to log in to the system, associated
  either with an existing user account or a preregistered user who has yet to
  log in.
  """

  use ArchiDep, :schema

  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount

  @derive {Inspect,
           only: [
             :id,
             :used_at,
             :user_account_id,
             :preregistered_user_id,
             :created_at
           ]}
  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          token: binary(),
          active: boolean(),
          used_at: DateTime.t() | nil,
          user_account: UserAccount.t() | nil | NotLoaded.t(),
          user_account_id: UUID.t() | nil,
          preregistered_user: PreregisteredUser.t() | nil | NotLoaded.t(),
          preregistered_user_id: UUID.t() | nil,
          created_at: DateTime.t()
        }

  schema "login_links" do
    field(:token, :binary, redact: true)
    field(:active, :boolean)
    field(:used_at, :utc_datetime_usec)
    belongs_to(:user_account, UserAccount)
    belongs_to(:preregistered_user, PreregisteredUser)
    field(:created_at, :utc_datetime_usec)
  end

  @spec fetch_valid_link_by_token(binary()) :: {:ok, t()} | {:error, :invalid_link}
  def fetch_valid_link_by_token(token),
    do:
      from(ll in __MODULE__,
        where: ll.token == ^token and ll.active and is_nil(ll.used_at),
        left_join: pu in assoc(ll, :preregistered_user),
        left_join: pug in assoc(pu, :group),
        left_join: pua in assoc(pu, :user_account),
        left_join: u in assoc(ll, :user_account),
        preload: [preregistered_user: {pu, group: pug, user_account: pua}, user_account: u]
      )
      |> Repo.one()
      |> truthy_or(:invalid_link)

  @spec new_token_for_preregistered_user_changeset(PreregisteredUser.t()) :: Changeset.t(t())
  def new_token_for_preregistered_user_changeset(preregistered_user) do
    id = UUID.generate()
    now = DateTime.utc_now()
    token = :crypto.strong_rand_bytes(100)

    %__MODULE__{}
    |> change(
      id: id,
      token: token,
      active: true,
      preregistered_user: preregistered_user,
      preregistered_user_id: preregistered_user.id,
      created_at: now
    )
    |> validate()
    |> validate_required([:id, :token, :preregistered_user, :preregistered_user_id, :created_at])
  end

  @spec mark_as_used_changeset(t()) :: Changeset.t(t())
  def mark_as_used_changeset(%__MODULE__{} = login_link),
    do:
      login_link
      |> change(%{used_at: DateTime.utc_now()})
      |> optimistic_lock(:active, fn true -> false end)
      |> validate()

  defp validate(changeset),
    do:
      validate_required(changeset, [
        :id,
        :token,
        :created_at
      ])
end
