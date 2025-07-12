defmodule ArchiDep.Accounts.Schemas.UserAccount do
  @moduledoc """
  A user account for someone who can log in to the application. The user may be
  an administrator or not.
  """

  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Types

  @derive {Inspect,
           only: [
             :id,
             :username,
             :roles,
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
          username: String.t(),
          roles: list(Types.role()),
          active: boolean(),
          switch_edu_id: SwitchEduId.t() | NotLoaded.t(),
          switch_edu_id_id: UUID.t(),
          preregistered_user: PreregisteredUser.t() | nil | NotLoaded.t(),
          preregistered_user_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @max_username_length 25

  schema "user_accounts" do
    field(:username, :string)
    field(:roles, {:array, Ecto.Enum}, values: [:root, :student])
    field(:active, :boolean)
    belongs_to(:switch_edu_id, SwitchEduId)
    belongs_to(:preregistered_user, PreregisteredUser, source: :student_id)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: active, roles: roles, preregistered_user: nil}, _now),
    do: active and Enum.member?(roles, :root)

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(
        %__MODULE__{active: active, roles: roles, preregistered_user: preregistered_user},
        now
      ),
      do:
        active and
          (Enum.member?(roles, :student) and PreregisteredUser.active?(preregistered_user, now))

  @spec student?(t()) :: boolean
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
        join: sei in assoc(ua, :switch_edu_id),
        where: ua.id == ^id,
        preload: [switch_edu_id: sei]
      )
      |> Repo.one!()

  @spec event_stream(String.t() | t()) :: String.t()
  def event_stream(id) when is_binary(id), do: "user-accounts:#{id}"
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

  @spec new_switch_edu_id_account(SwitchEduId.t(), list(Types.role())) :: Changeset.t(t())
  def new_switch_edu_id_account(switch_edu_id, roles) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(
      %{
        username:
          String.slice(
            switch_edu_id.first_name || String.replace(switch_edu_id.email, ~r/@.*/, ""),
            0,
            @max_username_length
          ),
        roles: roles
      },
      [
        :username,
        :roles
      ]
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

  @spec link_to_preregistered_user(
          t(),
          PreregisteredUser.t()
        ) :: Changeset.t(t())
  def link_to_preregistered_user(
        %__MODULE__{id: user_account_id, preregistered_user_id: nil} = user_account,
        preregistered_user
      ),
      do:
        user_account
        |> cast(%{preregistered_user_id: preregistered_user.id}, [:preregistered_user_id])
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

  defp validate(changeset),
    do:
      changeset
      |> update_change(:username, &trim/1)
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
