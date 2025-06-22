defmodule ArchiDep.Accounts.Schemas.UserAccount do
  @moduledoc """
  A user account for someone who can log in to the application. The user may be
  an administrator or not.
  """

  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Types
  alias ArchiDep.Students.Schemas.Student

  @derive {Inspect,
           only: [:id, :username, :roles, :active, :switch_edu_id_id, :student_id, :version]}
  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t(),
          roles: list(Types.role()),
          active: boolean(),
          switch_edu_id: SwitchEduId.t() | NotLoaded,
          switch_edu_id_id: UUID.t(),
          student: Student.t() | nil | NotLoaded,
          student_id: UUID.t() | nil,
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
    belongs_to(:student, Student)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: active, roles: roles, student: nil}, _now),
    do: active and Enum.member?(roles, :root)

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: active, roles: roles, student: student}, now),
    do:
      active and
        (Enum.member?(roles, :student) and Student.active?(student, now))

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

  @spec fetch_for_switch_edu_id(SwitchEduId.t()) :: t() | nil
  def fetch_for_switch_edu_id(%SwitchEduId{id: switch_edu_id_id}),
    do:
      Repo.one(
        from(ua in __MODULE__,
          join: sei in assoc(ua, :switch_edu_id),
          left_join: s in assoc(ua, :student),
          left_join: c in assoc(s, :class),
          where: sei.id == ^switch_edu_id_id,
          preload: [student: {s, class: c}, switch_edu_id: sei]
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
      active: true,
      switch_edu_id_id: switch_edu_id.id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate()
  end

  @spec link_to_student(
          t(),
          Student.t()
        ) :: Changeset.t(t())
  def link_to_student(%__MODULE__{id: user_account_id, student_id: nil} = user_account, student) do
    now = DateTime.utc_now()

    user_account
    |> cast(%{student_id: student.id}, [:student_id])
    |> assoc_constraint(:student)
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> unsafe_validate_unique_query(:student_id, Repo, fn changeset ->
      student_id = get_field(changeset, :student_id)

      from(ua in __MODULE__,
        where: ua.id != ^user_account_id and ua.student_id == ^student_id
      )
    end)
  end

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
