defmodule ArchiDep.Students.Schemas.User do
  @moduledoc """
  A user account for someone who can log in to the application. The user may be
  an administrator or not.
  """

  use ArchiDep, :schema

  alias ArchiDep.Students.Schemas.Student

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t(),
          student: Student.t() | nil | NotLoaded.t(),
          student_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "user_accounts" do
    field(:username, :string)
    belongs_to(:student, Student)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec fetch_user(UUID.t()) :: {:ok, t()} | {:error, :user_not_found}
  def fetch_user(id),
    do:
      from(u in __MODULE__,
        left_join: s in assoc(u, :student),
        left_join: sc in assoc(s, :class),
        where: u.id == ^id,
        preload: [student: {s, class: sc}]
      )
      |> Repo.one()
      |> truthy_or(:user_not_found)

  @spec refresh!(t(), map()) :: t()
  def refresh!(%__MODULE__{id: id, student: student, version: current_version} = user, %{
        id: id,
        username: username,
        preregistered_user: preregistered_user,
        preregistered_user_id: preregistered_user_id,
        version: version,
        updated_at: updated_at
      })
      when version == current_version + 1 and not is_nil(student) and
             not is_nil(preregistered_user) do
    %__MODULE__{
      user
      | username: username,
        student: Student.refresh!(student, preregistered_user),
        student_id: preregistered_user_id,
        version: version,
        updated_at: updated_at
    }
  end

  @spec refresh!(t(), map()) :: t()
  def refresh!(%__MODULE__{id: id, version: current_version} = user, %{
        id: id,
        version: version
      })
      when version <= current_version do
    user
  end

  @spec refresh!(t(), map()) :: t()
  def refresh!(%__MODULE__{id: id}, %{id: id}) do
    {:ok, fresh_user} = fetch_user(id)
    fresh_user
  end
end
