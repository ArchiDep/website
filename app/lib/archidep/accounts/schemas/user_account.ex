defmodule ArchiDep.Accounts.Schemas.UserAccount do
  @moduledoc """
  A user account for someone who can log in to the application. The user may be
  an administrator or not.
  """

  use ArchiDep, :schema

  import ArchiDep.Accounts.Schemas.UserGroup, only: [where_user_group_active: 1]
  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Events.Store.EventInitiator

  @derive {Inspect,
           only: [
             :id,
             :username,
             :root,
             :active,
             :switch_edu_id_id,
             :preregistered_user_id,
             :version
           ]}
  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t() | nil,
          root: boolean(),
          active: boolean(),
          switch_edu_id: SwitchEduId.t() | NotLoaded.t(),
          switch_edu_id_id: UUID.t(),
          preregistered_user: PreregisteredUser.t() | nil | NotLoaded.t(),
          preregistered_user_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "user_accounts" do
    field(:username, :string)
    field(:root, :boolean)
    field(:active, :boolean)
    belongs_to(:switch_edu_id, SwitchEduId)
    belongs_to(:preregistered_user, PreregisteredUser, source: :student_id)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: active, root: true, preregistered_user: nil}, _now), do: active

  def active?(
        %__MODULE__{active: active, root: false, preregistered_user: preregistered_user},
        now
      ),
      do: active and PreregisteredUser.active?(preregistered_user, now)

  def active?(_account, _now), do: false

  @spec count_active_users(DateTime.t()) :: non_neg_integer
  def count_active_users(now),
    do:
      Repo.aggregate(
        from(ua in __MODULE__,
          as: :user_account,
          left_join: pu in assoc(ua, :preregistered_user),
          as: :preregistered_user,
          left_join: ug in assoc(pu, :group),
          as: :user_group,
          where: ^where_user_account_active(now)
        ),
        :count,
        :id
      )

  @spec where_user_account_active(DateTime.t()) :: Queryable.t()
  def where_user_account_active(now),
    do:
      dynamic(
        [user_account: ua, preregistered_user: pu, user_group: ug],
        (ua.active and (ua.root and is_nil(pu))) or
          (not ua.root and not is_nil(pu) and pu.active and
             ^where_user_group_active(now))
      )

  @spec get_with_switch_edu_id!(UUID.t()) :: t
  def get_with_switch_edu_id!(id),
    do:
      Repo.one!(
        from(ua in __MODULE__,
          join: sei in assoc(ua, :switch_edu_id),
          where: ua.id == ^id,
          preload: [switch_edu_id: sei]
        )
      )

  @spec event_stream(String.t() | t()) :: String.t()
  def event_stream(id) when is_binary(id), do: "accounts:user-accounts:#{id}"
  def event_stream(%__MODULE__{id: id}), do: event_stream(id)

  @spec fetch_by_id(UUID.t()) :: {:ok, t()} | {:error, :user_account_not_found}
  def fetch_by_id(user_account_id) do
    case Repo.one(
           from(ua in __MODULE__,
             left_join: pu in assoc(ua, :preregistered_user),
             left_join: ug in assoc(pu, :group),
             where: ua.id == ^user_account_id,
             preload: [preregistered_user: {pu, group: ug}]
           )
         ) do
      nil -> {:error, :user_account_not_found}
      user_account -> {:ok, user_account}
    end
  end

  @spec fetch_for_switch_edu_id(SwitchEduId.t()) :: t() | nil
  def fetch_for_switch_edu_id(%SwitchEduId{id: switch_edu_id_id}),
    do:
      Repo.one(
        from(ua in __MODULE__,
          join: sei in assoc(ua, :switch_edu_id),
          left_join: pu in assoc(ua, :preregistered_user),
          left_join: ug in assoc(pu, :group),
          where: sei.id == ^switch_edu_id_id,
          preload: [preregistered_user: {pu, group: ug}, switch_edu_id: sei]
        )
      )

  @spec new_root_switch_edu_id_account(SwitchEduId.t(), String.t()) :: Changeset.t(t())
  def new_root_switch_edu_id_account(switch_edu_id, matched_identifier) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(
      %{username: matched_identifier, root: true},
      [:username, :root]
    )
    |> change(
      id: id,
      active: true,
      switch_edu_id_id: switch_edu_id.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
  end

  @spec new_preregistered_switch_edu_id_account(
          SwitchEduId.t(),
          PreregisteredUser.t()
        ) :: Changeset.t(t())
  def new_preregistered_switch_edu_id_account(switch_edu_id, preregistered_user) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(
      %{username: nil, root: false},
      [:username, :root]
    )
    |> change(
      id: id,
      active: true,
      switch_edu_id_id: switch_edu_id.id,
      preregistered_user: preregistered_user,
      preregistered_user_id: preregistered_user.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
  end

  @spec relink_to_preregistered_user(
          t(),
          PreregisteredUser.t()
        ) :: Changeset.t(t())
  def relink_to_preregistered_user(
        %__MODULE__{id: user_account_id} = user_account,
        new_preregistered_user
      ),
      do:
        user_account
        |> cast(%{preregistered_user_id: new_preregistered_user.id}, [:preregistered_user_id])
        |> assoc_constraint(:preregistered_user)
        |> change(updated_at: DateTime.utc_now())
        |> optimistic_lock(:version)
        |> unsafe_validate_unique_query(:preregistered_user_id, Repo, fn changeset ->
          preregistered_user_id = get_field(changeset, :preregistered_user_id)

          from(ua in __MODULE__,
            where:
              ua.id != ^user_account_id and ua.preregistered_user_id == ^preregistered_user_id
          )
        end)

  defimpl EventInitiator do
    alias ArchiDep.Accounts.Schemas.UserAccount

    @spec event_initiator_stream(UserAccount.t()) :: String.t()
    def event_initiator_stream(user_account), do: UserAccount.event_stream(user_account)
  end

  defp validate(changeset),
    do:
      changeset
      |> update_change(:username, &trim_to_nil/1)
      |> validate_required([
        :id,
        :root,
        :version,
        :created_at,
        :updated_at
      ])
end
