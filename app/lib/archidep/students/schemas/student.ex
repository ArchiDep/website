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
          class: Class.t() | NotLoaded,
          class_id: UUID.t(),
          user_account: UserAccount.t() | nil | NotLoaded,
          user_account_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "students" do
    field(:name, :binary)
    field(:email, :binary)
    belongs_to(:class, Class)
    belongs_to(:user_account, UserAccount)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec new(Types.student_data()) :: Changeset.t(t())
  def new(data) do
    id = UUID.generate()
    now = DateTime.utc_now()

    %__MODULE__{}
    |> cast(data, [:name, :email, :class_id])
    |> change(
      id: id,
      version: 1,
      created_at: now,
      updated_at: now
    )
    |> validate_length(:name, max: 100)
    |> validate_format(:name, ~r/\A\S.*\z/, message: "must not start with whitespace")
    |> validate_format(:name, ~r/\A.*\S\z/, message: "must not end with whitespace")
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
end
