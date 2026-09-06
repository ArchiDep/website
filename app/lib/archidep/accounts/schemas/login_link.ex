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

  # How long a link may be followed after it was generated. A link is a bearer
  # token in a URL — it leaks through browser history, proxy and server logs and
  # `Referer` headers — so being single-use is not on its own enough: an
  # unfollowed link would otherwise stay usable for as long as its student's
  # class runs. Two days covers a student who is given a link during a class and
  # only gets to it the next day; a teacher generates another whenever one has
  # lapsed.
  @link_validity_in_hours 48
  @one_hour_in_seconds 60 * 60
  @token_bytes 100

  @type t :: %__MODULE__{
          id: UUID.t(),
          token_hash: binary(),
          raw_token: binary() | nil,
          active: boolean(),
          used_at: DateTime.t() | nil,
          user_account: UserAccount.t() | nil | NotLoaded.t(),
          user_account_id: UUID.t() | nil,
          preregistered_user: PreregisteredUser.t() | nil | NotLoaded.t(),
          preregistered_user_id: UUID.t() | nil,
          created_at: DateTime.t()
        }

  schema "login_links" do
    # The hash of the link's token, never the token itself — a link is a bearer
    # credential in a URL, and a row that held it would let anyone who can read
    # this table log in as the student it was issued for. A link is found by
    # hashing the token in the URL and comparing that.
    field(:token_hash, :binary, redact: true)
    # The token itself, held only in memory and only on the one path that has
    # it: the link that was just generated, whose URL the teacher is shown.
    field(:raw_token, :binary, virtual: true, redact: true)
    field(:active, :boolean)
    field(:used_at, :utc_datetime_usec)
    belongs_to(:user_account, UserAccount)
    belongs_to(:preregistered_user, PreregisteredUser)
    field(:created_at, :utc_datetime_usec)
  end

  @spec fetch_valid_link_by_token(binary(), DateTime.t()) :: {:ok, t()} | {:error, :invalid_link}
  def fetch_valid_link_by_token(token, now),
    do:
      from(ll in __MODULE__,
        where:
          ll.token_hash == ^hash_token(token) and ll.active and is_nil(ll.used_at) and
            ll.created_at > ^link_validity_cutoff(now),
        left_join: pu in assoc(ll, :preregistered_user),
        left_join: pug in assoc(pu, :group),
        left_join: pua in assoc(pu, :user_account),
        left_join: u in assoc(ll, :user_account),
        preload: [preregistered_user: {pu, group: pug, user_account: pua}, user_account: u]
      )
      |> Repo.one()
      |> truthy_or(:invalid_link)

  @spec new_token_for_preregistered_user_changeset(PreregisteredUser.t(), DateTime.t()) ::
          Changeset.t(t())
  def new_token_for_preregistered_user_changeset(preregistered_user, now) do
    id = UUID.generate()
    raw_token = :crypto.strong_rand_bytes(@token_bytes)

    %__MODULE__{}
    |> change(
      id: id,
      token_hash: hash_token(raw_token),
      raw_token: raw_token,
      active: true,
      preregistered_user: preregistered_user,
      preregistered_user_id: preregistered_user.id,
      created_at: now
    )
    |> validate()
    |> validate_required([
      :id,
      :token_hash,
      :preregistered_user,
      :preregistered_user_id,
      :created_at
    ])
  end

  @spec mark_as_used_changeset(t(), DateTime.t()) :: Changeset.t(t())
  def mark_as_used_changeset(%__MODULE__{} = login_link, now),
    do:
      login_link
      |> change(%{used_at: now})
      |> optimistic_lock(:active, fn true -> false end)
      |> validate()

  defp validate(changeset),
    do:
      validate_required(changeset, [
        :id,
        :token_hash,
        :created_at
      ])

  # A plain digest rather than a password hash, for the reason given in
  # `ArchiDep.Accounts.Schemas.UserSession`: the token is a long random value,
  # so only irreversibility is wanted.
  defp hash_token(token), do: :crypto.hash(:sha256, token)

  # The earliest creation instant a link may have and still be followed. Derived
  # from the injected clock so the validity window is deterministic and can be
  # pinned in tests.
  defp link_validity_cutoff(now),
    do: DateTime.add(now, -@link_validity_in_hours * @one_hour_in_seconds, :second)
end
