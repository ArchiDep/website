defmodule ArchiDep.Students.Schemas.Student do
  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t(),
          academic_class: String.t() | nil,
          class: Class.t() | NotLoaded,
          class_id: UUID.t(),
          user_account: UserAccount.t() | nil | NotLoaded,
          user_account_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "students" do
    field(:name, :string)
    field(:email, :string)
    field(:academic_class, :string)
    belongs_to(:class, Class)
    belongs_to(:user_account, UserAccount)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec new(Types.create_student_data()) :: Changeset.t(t())
  def new(data) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [:name, :email, :academic_class, :class_id])
    |> change(
      id: id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> update_change(:name, &trim/1)
    |> update_change(:email, &trim/1)
    |> update_change(:academic_class, &trim_to_nil/1)
    |> validate_length(:name, max: 200)
    |> validate_length(:email, max: 255)
    |> validate_format(:email, ~r/\A.+@.+\..+\z/, message: "must be a valid email address")
    |> validate_length(:academic_class, max: 30)
    |> validate_required([:name, :email, :class_id])
    |> unique_constraint(:email, name: :students_unique_email_index)
    |> unsafe_validate_unique_query(:email, Repo, fn changeset ->
      class_id = get_field(changeset, :class_id)
      email = get_field(changeset, :email)

      from(s in __MODULE__,
        where:
          s.class_id == ^class_id and
            fragment("LOWER(?)", s.email) == fragment("LOWER(?)", ^email)
      )
    end)
    |> assoc_constraint(:class)
  end

  @spec fetch_student(UUID.t()) :: {:ok, t()} | {:error, :student_not_found}
  def fetch_student(id) do
    case Repo.get(__MODULE__, id) do
      nil ->
        {:error, :student_not_found}

      student ->
        {:ok, student}
    end
  end

  @spec fetch_student_in_class(UUID.t(), UUID.t()) :: {:ok, t()} | {:error, :student_not_found}
  def fetch_student_in_class(class_id, id) do
    case Repo.one(
           from(s in __MODULE__,
             where: s.class_id == ^class_id and s.id == ^id,
             join: c in assoc(s, :class),
             left_join: ua in assoc(s, :user_account),
             preload: [:class, :user_account]
           )
         ) do
      nil ->
        {:error, :student_not_found}

      student ->
        {:ok, student}
    end
  end

  @spec update(__MODULE__.t(), Types.existing_student_data()) :: Changeset.t(t())
  def update(student, data) do
    id = student.id
    class_id = student.class_id
    now = DateTime.utc_now()

    student
    |> cast(data, [:name, :email, :academic_class])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    |> update_change(:name, &trim/1)
    |> update_change(:email, &trim/1)
    |> update_change(:academic_class, &trim_to_nil/1)
    |> validate_length(:name, max: 200)
    |> validate_length(:email, max: 255)
    |> validate_format(:email, ~r/\A.+@.+\..+\z/, message: "must be a valid email address")
    |> validate_length(:academic_class, max: 30)
    |> validate_required([:name, :email, :class_id])
    |> unique_constraint(:email, name: :students_unique_email_index)
    |> unsafe_validate_unique_query(:email, Repo, fn changeset ->
      email = get_field(changeset, :email)

      from(s in __MODULE__,
        where:
          s.id != ^id and s.class_id == ^class_id and
            fragment("LOWER(?)", s.email) == fragment("LOWER(?)", ^email)
      )
    end)
    |> assoc_constraint(:class)
  end

  @spec link_to_user_account(
          t(),
          UserAccount.t()
        ) :: Changeset.t(t())
  def link_to_user_account(%__MODULE__{user_account_id: nil} = student, user_account) do
    now = DateTime.utc_now()

    student
    |> cast(%{user_account_id: user_account.id}, [:user_account_id])
    |> assoc_constraint(:user_account)
    |> change(updated_at: now)
    |> optimistic_lock(:version)
  end

  @spec delete_students_in_class(Class.t()) :: Query.t()
  def delete_students_in_class(%Class{id: class_id}),
    do: from(s in __MODULE__, where: s.class_id == ^class_id)
end
